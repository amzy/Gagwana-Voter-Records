# Gagwana Voter Records

Mobile-first Flutter web UI concept for Gagwana voter-list search and PDF import review.

## Current starter features
- Responsive Material 3 layout for mobile and desktop
- Light and dark theme toggle
- Hindi voter search by name, relative name, voter ID, or serial number
- Ward and active/flagged/deleted filters
- Voter detail sheet with source PDF/page metadata
- PDF picker and OCR settings UI

## Run locally
Install Flutter stable, then run:

```bash
flutter pub get
flutter run -d chrome --web-port=7357
```

## GitHub Pages
The workflow at `.github/workflows/deploy-pages.yml` builds the Flutter web app and deploys it when changes are pushed to `main` (including a pull request merge). Pull requests targeting `main` run the build but do not publish.

In GitHub, open **Settings → Pages** and set **Build and deployment → Source** to **GitHub Actions**. The published site will be available at:

https://amzy.github.io/Gagwana-Voter-Records/

## SQL backend (SQLite)

A small FastAPI backend is available in `backend/`. It uses one persistent SQLite file (`voter_records.db`), which is appropriate for a few thousand records and does not require a separate database server. Do not put the database file in the Flutter web build or a temporary container filesystem.

### Run locally

Install Python 3.12+, Tesseract with Hindi language data, and Poppler (used by PDF rendering). Then:

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
export VOTER_DB_PATH="$PWD/data/voter_records.db"
export VOTER_API_TOKEN="replace-with-a-long-random-secret"
# Match the exact Flutter debug origin used below.
export VOTER_ALLOWED_ORIGINS="http://localhost:7357,http://127.0.0.1:7357"
uvicorn app:app --reload --port 8080
```

The API requires `Authorization: Bearer <VOTER_API_TOKEN>` for voter data and import endpoints. `GET /health` is public and contains no voter data. Set `VOTER_ALLOWED_ORIGINS` to the exact deployed Flutter origin(s) when browser access is needed. Never ship the API token inside a public Flutter web build. Use an authenticated proxy/backend for browser sessions and mount `/data` on persistent server storage. Back up the SQLite file regularly.

### Docker deployment with persistent storage

From `backend/`, configure `VOTER_API_TOKEN` in your shell or deployment secret manager, then run:

```bash
export VOTER_API_TOKEN="$(python3 -c 'import secrets; print(secrets.token_urlsafe(48))')"
docker compose up --build -d
```

Docker Compose keeps the database in the named `voter_data` volume and binds port 8080 to localhost only. Put a TLS-enabled authenticated reverse proxy in front of it for remote use. Back up the named volume; a container image or redeploy is not a backup.

### Connect the Flutter debug app

1. Start the backend in one terminal using the commands above.
2. In another terminal, run Flutter on the matching fixed port: `flutter run -d chrome --web-port=7357`.
3. Open **Import PDFs**. Enter `http://127.0.0.1:8080` as Backend URL and the same `VOTER_API_TOKEN` value in the API token field.
4. Select PDFs and click **Upload PDFs and scan**. The app shows per-file errors, duplicate-upload messages, and extracted page text.

If Flutter is running on a different port, update `VOTER_ALLOWED_ORIGINS` to match that exact origin and restart the backend. The token field is entered at runtime; do not hard-code the token into Flutter source or ship a shared admin token in a public web app.

### API endpoints

- `POST /imports/pdf` — upload a PDF, extract embedded page text, and use Tesseract Hindi+English OCR when the page appears scanned. Stores page-level extraction in SQLite and returns a batch ID.
- `GET /imports/{batch_id}/pages` — retrieve staged page text for review.
- `POST /imports/preview` — preview record merge counts without changing voter records.
- `POST /imports/commit` — commit reviewed, structured records transactionally after `confirm: true`.
- `GET /records` — search/paginate saved records.
- `GET /imports` — import history.

Commit requests require a batch ID created by scanning a PDF. Voter IDs are normalized for deduplication. Empty fields do not overwrite existing data; missing incoming photos never erase saved photos; explicit deletion evidence is required to set a record as deleted; uncertain/low-confidence records can be flagged for review. Import actions are written to an audit table.

### Current limitations (important)

The Flutter interface is not yet connected to these endpoints. PDF scanning currently stages per-page extracted/OCR text; it does **not** automatically parse each page into reliable structured voter rows, extract and align voter photos, or visually verify DELETED stamps. Those tasks require a layout-aware parser and a review UI before the resulting records should be committed. The API intentionally expects structured records at preview/commit, rather than silently treating raw OCR text as verified data. The existing Flutter voter list is still demonstration data until the app is wired to the backend.

