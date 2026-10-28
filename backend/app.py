"""Persistent SQLite API and PDF text/OCR staging for Gagwana Voter Records.

The SQLite file must be mounted on persistent server storage. PDF pages are
staged for review; OCR text is not treated as verified voter data.
"""
from __future__ import annotations

import hashlib
import io
import os
import re
import sqlite3
import uuid
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import pdfplumber
import pytesseract
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from PIL import Image
from pydantic import BaseModel, Field

DB_PATH = Path(os.environ.get("VOTER_DB_PATH", "./data/voter_records.db"))
MAX_PDF_BYTES = int(os.environ.get("MAX_PDF_BYTES", str(30 * 1024 * 1024)))
MAX_PAGES = int(os.environ.get("MAX_PDF_PAGES", "300"))
DB_PATH.parent.mkdir(parents=True, exist_ok=True)

app = FastAPI(title="Gagwana Voter Records API", version="1.0.0")
# Set VOTER_ALLOWED_ORIGINS to a comma-separated allowlist in deployment.
origins = [x.strip() for x in os.environ.get("VOTER_ALLOWED_ORIGINS", "").split(",") if x.strip()]
if origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=origins,
        allow_credentials=False,
        allow_methods=["GET", "POST"],
        allow_headers=["Content-Type", "Authorization"],
    )


def now() -> str:
    return datetime.now(timezone.utc).isoformat()


def normalize_voter_id(value: str) -> str:
    return re.sub(r"[^A-Z0-9]", "", value.upper())


@contextmanager
def connection():
    conn = sqlite3.connect(DB_PATH, timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    conn.execute("PRAGMA journal_mode = WAL")
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def initialize() -> None:
    with connection() as db:
        db.executescript("""
        CREATE TABLE IF NOT EXISTS voters (
            voter_id TEXT PRIMARY KEY,
            normalized_voter_id TEXT NOT NULL UNIQUE,
            serial_number TEXT NOT NULL DEFAULT '',
            ward TEXT NOT NULL DEFAULT '',
            name TEXT NOT NULL DEFAULT '',
            relative_name TEXT NOT NULL DEFAULT '',
            relation_type TEXT NOT NULL DEFAULT '',
            house_no TEXT NOT NULL DEFAULT '',
            age INTEGER,
            gender TEXT NOT NULL DEFAULT '',
            photo_path TEXT,
            is_deleted INTEGER NOT NULL DEFAULT 0 CHECK(is_deleted IN (0,1)),
            deleted_evidence TEXT NOT NULL DEFAULT '',
            source_pdf TEXT NOT NULL DEFAULT '',
            source_page INTEGER,
            review_required INTEGER NOT NULL DEFAULT 0 CHECK(review_required IN (0,1)),
            raw_text TEXT NOT NULL DEFAULT '',
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_voters_ward ON voters(ward);
        CREATE INDEX IF NOT EXISTS idx_voters_name ON voters(name);
        CREATE TABLE IF NOT EXISTS import_batches (
            batch_id TEXT PRIMARY KEY,
            filename TEXT NOT NULL,
            sha256 TEXT NOT NULL,
            page_count INTEGER NOT NULL DEFAULT 0,
            status TEXT NOT NULL,
            created_at TEXT NOT NULL,
            UNIQUE(sha256)
        );
        CREATE TABLE IF NOT EXISTS import_pages (
            batch_id TEXT NOT NULL REFERENCES import_batches(batch_id) ON DELETE CASCADE,
            page_number INTEGER NOT NULL,
            extracted_text TEXT NOT NULL DEFAULT '',
            extraction_method TEXT NOT NULL DEFAULT 'text',
            review_required INTEGER NOT NULL DEFAULT 1,
            PRIMARY KEY(batch_id, page_number)
        );
        CREATE TABLE IF NOT EXISTS import_audit (
            audit_id INTEGER PRIMARY KEY AUTOINCREMENT,
            batch_id TEXT NOT NULL,
            voter_id TEXT NOT NULL,
            action TEXT NOT NULL,
            source_pdf TEXT NOT NULL,
            source_page INTEGER,
            created_at TEXT NOT NULL,
            details TEXT NOT NULL DEFAULT ''
        );
        """)


@app.on_event("startup")
def startup() -> None:
    initialize()


class ImportRecord(BaseModel):
    voter_id: str = Field(min_length=1, max_length=100)
    serial_number: str = ""
    ward: str = ""
    name: str = ""
    relative_name: str = ""
    relation_type: str = ""
    house_no: str = ""
    age: int | None = None
    gender: str = ""
    photo_path: str | None = None
    source_pdf: str = ""
    source_page: int | None = None
    raw_text: str = ""
    confidence: float | None = Field(default=None, ge=0, le=1)
    deleted_mark_detected: bool = False
    deleted_evidence: str = ""
    review_required: bool = False


class PreviewRequest(BaseModel):
    records: list[ImportRecord] = Field(max_length=10000)


class CommitRequest(PreviewRequest):
    confirm: bool = False
    batch_id: str = Field(min_length=1, max_length=100)


def row_to_dict(row: sqlite3.Row) -> dict[str, Any]:
    item = dict(row)
    item["is_deleted"] = bool(item["is_deleted"])
    item["review_required"] = bool(item["review_required"])
    return item


@app.get("/health")
def health():
    initialize()
    return {"status": "ok", "storage": "sqlite", "database_file_configured": str(DB_PATH)}


@app.get("/records")
def list_records(q: str = "", ward: str = "", limit: int = 100, offset: int = 0):
    limit = max(1, min(limit, 500))
    offset = max(0, offset)
    clauses, params = [], []
    if q.strip():
        needle = f"%{q.strip()}%"
        clauses.append("(voter_id LIKE ? OR name LIKE ? OR relative_name LIKE ? OR serial_number LIKE ?)")
        params.extend([needle] * 4)
    if ward.strip():
        clauses.append("ward = ?")
        params.append(ward.strip())
    where = (" WHERE " + " AND ".join(clauses)) if clauses else ""
    with connection() as db:
        total = db.execute("SELECT COUNT(*) FROM voters" + where, params).fetchone()[0]
        rows = db.execute(
            "SELECT * FROM voters" + where + " ORDER BY ward, CAST(serial_number AS INTEGER), voter_id LIMIT ? OFFSET ?",
            [*params, limit, offset],
        ).fetchall()
    return {"total": total, "limit": limit, "offset": offset, "records": [row_to_dict(r) for r in rows]}


@app.post("/imports/pdf")
async def scan_pdf(file: UploadFile = File(...)):
    """Extract text per page; OCR scanned pages in Hindi+English and stage for review."""
    filename = Path(file.filename or "upload.pdf").name
    if not filename.lower().endswith(".pdf"):
        raise HTTPException(415, "Only PDF files are accepted.")
    content = await file.read(MAX_PDF_BYTES + 1)
    if len(content) > MAX_PDF_BYTES:
        raise HTTPException(413, f"PDF exceeds {MAX_PDF_BYTES} bytes.")
    if not content.startswith(b"%PDF-"):
        raise HTTPException(400, "The uploaded file is not a valid PDF.")
    digest = hashlib.sha256(content).hexdigest()
    batch_id = uuid.uuid4().hex
    staged: list[tuple[int, str, str, bool]] = []
    try:
        with pdfplumber.open(io.BytesIO(content)) as pdf:
            if len(pdf.pages) > MAX_PAGES:
                raise HTTPException(413, f"PDF exceeds {MAX_PAGES} pages.")
            for page_no, page in enumerate(pdf.pages, start=1):
                text = (page.extract_text(layout=True) or "").strip()
                method = "embedded-text"
                # Sparse embedded text often indicates a scanned page. Render it for OCR.
                if len(re.sub(r"\s+", "", text)) < 35:
                    try:
                        image = page.to_image(resolution=220).original
                        text = pytesseract.image_to_string(image, lang="hin+eng").strip()
                        method = "tesseract-hin+eng"
                    except Exception as exc:
                        text = text or f"[OCR unavailable: {type(exc).__name__}]"
                        method = "ocr-error"
                staged.append((page_no, text, method, True))
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(400, f"Could not read PDF: {type(exc).__name__}") from exc

    with connection() as db:
        previous = db.execute("SELECT batch_id FROM import_batches WHERE sha256=?", (digest,)).fetchone()
        if previous:
            return {"duplicate_upload": True, "existing_batch_id": previous["batch_id"],
                    "filename": filename, "message": "This exact PDF was already scanned."}
        db.execute(
            "INSERT INTO import_batches(batch_id,filename,sha256,page_count,status,created_at) VALUES(?,?,?,?,?,?)",
            (batch_id, filename, digest, len(staged), "scanned_needs_record_review", now()),
        )
        db.executemany(
            "INSERT INTO import_pages(batch_id,page_number,extracted_text,extraction_method,review_required) VALUES(?,?,?,?,?)",
            [(batch_id, p, text, method, int(review)) for p, text, method, review in staged],
        )
    return {
        "batch_id": batch_id, "filename": filename, "sha256": digest,
        "page_count": len(staged), "status": "scanned_needs_record_review",
        "pages": [{"page": p, "method": method, "text": text, "review_required": review}
                  for p, text, method, review in staged],
        "message": "Page text is staged. Verify parsed voter fields before committing; OCR text is not automatically trusted.",
    }


@app.get("/imports/{batch_id}/pages")
def get_import_pages(batch_id: str):
    with connection() as db:
        batch = db.execute("SELECT * FROM import_batches WHERE batch_id=?", (batch_id,)).fetchone()
        if not batch:
            raise HTTPException(404, "Import batch not found.")
        pages = db.execute(
            "SELECT page_number,extraction_method,extracted_text,review_required FROM import_pages WHERE batch_id=? ORDER BY page_number",
            (batch_id,),
        ).fetchall()
    return {"batch": dict(batch), "pages": [dict(p) for p in pages]}


@app.post("/imports/preview")
def preview_import(request: PreviewRequest):
    """Compute merge counts without writing voter records."""
    incoming: dict[str, ImportRecord] = {}
    duplicates = 0
    invalid = 0
    for record in request.records:
        key = normalize_voter_id(record.voter_id)
        if not key:
            invalid += 1
            continue
        if key in incoming:
            duplicates += 1
        incoming[key] = record
    new_count = updated_count = unchanged_count = 0
    with connection() as db:
        for key, record in incoming.items():
            old = db.execute("SELECT * FROM voters WHERE normalized_voter_id=?", (key,)).fetchone()
            if old is None:
                new_count += 1
                continue
            proposed = record.model_dump()
            changes = any(
                proposed[field] not in (None, "") and proposed[field] != old[db_field]
                for field, db_field in [
                    ("serial_number", "serial_number"), ("ward", "ward"), ("name", "name"),
                    ("relative_name", "relative_name"), ("relation_type", "relation_type"),
                    ("house_no", "house_no"), ("gender", "gender"), ("age", "age"),
                    ("photo_path", "photo_path"),
                ]
            ) or (record.deleted_mark_detected and not old["is_deleted"])
            if changes:
                updated_count += 1
            else:
                unchanged_count += 1
    return {"incoming_count": len(request.records), "unique_ids": len(incoming),
            "new": new_count, "would_update": updated_count, "unchanged": unchanged_count,
            "duplicates_in_batch": duplicates, "missing_ids_for_review": invalid,
            "requires_confirmation": True}


@app.post("/imports/commit")
def commit_import(request: CommitRequest):
    if not request.confirm:
        raise HTTPException(400, "Set confirm=true after reviewing the preview.")
    incoming: dict[str, ImportRecord] = {}
    for record in request.records:
        key = normalize_voter_id(record.voter_id)
        if not key:
            raise HTTPException(422, "A record has no usable voter ID; review it before committing.")
        incoming[key] = record
    added = updated = unchanged = 0
    timestamp = now()
    with connection() as db:
        batch = db.execute("SELECT * FROM import_batches WHERE batch_id=?", (request.batch_id,)).fetchone()
        if not batch:
            raise HTTPException(404, "Scan the PDF first; batch ID not found.")
        for key, record in incoming.items():
            old = db.execute("SELECT * FROM voters WHERE normalized_voter_id=?", (key,)).fetchone()
            new_photo = record.photo_path.strip() if record.photo_path and record.photo_path.strip() else None
            if old is None:
                db.execute("""INSERT INTO voters
                    (voter_id,normalized_voter_id,serial_number,ward,name,relative_name,relation_type,
                     house_no,age,gender,photo_path,is_deleted,deleted_evidence,source_pdf,source_page,
                     review_required,raw_text,created_at,updated_at)
                    VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
                    (record.voter_id.strip(), key, record.serial_number, record.ward, record.name,
                     record.relative_name, record.relation_type, record.house_no, record.age, record.gender,
                     new_photo, int(record.deleted_mark_detected), record.deleted_evidence if record.deleted_mark_detected else "",
                     record.source_pdf or batch["filename"], record.source_page, int(record.review_required or record.confidence is not None and record.confidence < 0.85),
                     record.raw_text, timestamp, timestamp))
                action = "inserted"
                added += 1
            else:
                values = {
                    "voter_id": record.voter_id.strip() or old["voter_id"],
                    "serial_number": record.serial_number or old["serial_number"],
                    "ward": record.ward or old["ward"], "name": record.name or old["name"],
                    "relative_name": record.relative_name or old["relative_name"],
                    "relation_type": record.relation_type or old["relation_type"],
                    "house_no": record.house_no or old["house_no"],
                    "age": record.age if record.age is not None else old["age"],
                    "gender": record.gender or old["gender"],
                    # Never erase an existing photo when incoming photo is absent.
                    "photo_path": new_photo or old["photo_path"],
                    # Only an explicit mark can transition a record to deleted.
                    "is_deleted": 1 if record.deleted_mark_detected else old["is_deleted"],
                    "deleted_evidence": record.deleted_evidence if record.deleted_mark_detected and record.deleted_evidence else old["deleted_evidence"],
                    "source_pdf": record.source_pdf or batch["filename"],
                    "source_page": record.source_page if record.source_page is not None else old["source_page"],
                    "review_required": int(bool(old["review_required"]) or record.review_required or (record.confidence is not None and record.confidence < 0.85)),
                    "raw_text": record.raw_text or old["raw_text"],
                    "updated_at": timestamp,
                }
                changed = any(values[k] != old[k] for k in values)
                if changed:
                    db.execute("""UPDATE voters SET voter_id=:voter_id,serial_number=:serial_number,
                        ward=:ward,name=:name,relative_name=:relative_name,relation_type=:relation_type,
                        house_no=:house_no,age=:age,gender=:gender,photo_path=:photo_path,
                        is_deleted=:is_deleted,deleted_evidence=:deleted_evidence,source_pdf=:source_pdf,
                        source_page=:source_page,review_required=:review_required,raw_text=:raw_text,
                        updated_at=:updated_at WHERE normalized_voter_id=:normalized""",
                        {**values, "normalized": key})
                    action = "updated"
                    updated += 1
                else:
                    action = "unchanged"
                    unchanged += 1
            db.execute("""INSERT INTO import_audit(batch_id,voter_id,action,source_pdf,source_page,created_at,details)
                          VALUES(?,?,?,?,?,?,?)""",
                       (request.batch_id, record.voter_id, action, record.source_pdf or batch["filename"],
                        record.source_page, timestamp, "explicit deletion mark detected" if record.deleted_mark_detected else ""))
        db.execute("UPDATE import_batches SET status='committed' WHERE batch_id=?", (request.batch_id,))
    return {"batch_id": request.batch_id, "inserted": added, "updated": updated,
            "unchanged": unchanged, "committed": True}


@app.get("/imports")
def list_imports(limit: int = 100):
    with connection() as db:
        rows = db.execute("SELECT batch_id,filename,sha256,page_count,status,created_at FROM import_batches ORDER BY created_at DESC LIMIT ?",
                          (max(1, min(limit, 500)),)).fetchall()
    return {"imports": [dict(r) for r in rows]}
