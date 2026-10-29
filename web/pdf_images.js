(function () {
  const OPS_URL = 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.min.js';
  function loadPdfJs() {
    if (window.pdfjsLib) return Promise.resolve(window.pdfjsLib);
    return new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = OPS_URL;
      script.onload = () => {
        if (!window.pdfjsLib) return reject(new Error('PDF.js did not initialise.'));
        window.pdfjsLib.GlobalWorkerOptions.workerSrc =
          'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js';
        resolve(window.pdfjsLib);
      };
      script.onerror = () => reject(new Error('Could not load PDF.js. Check internet and reload.'));
      document.head.appendChild(script);
    });
  }
  const TESSERACT_URL = 'https://cdn.jsdelivr.net/npm/tesseract.js@5.1.1/dist/tesseract.min.js';
  let tesseractPromise = null;
  let ocrWorkerPromise = null;
  function loadTesseract() {
    if (window.Tesseract) return Promise.resolve(window.Tesseract);
    if (!tesseractPromise) tesseractPromise = new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = TESSERACT_URL;
      script.onload = () => window.Tesseract
        ? resolve(window.Tesseract)
        : reject(new Error('Hindi OCR library did not initialise.'));
      script.onerror = () => reject(new Error('Could not load Hindi OCR. Check internet and reload.'));
      document.head.appendChild(script);
    });
    return tesseractPromise;
  }
  async function getOcrWorker() {
    const Tesseract = await loadTesseract();
    if (!ocrWorkerPromise) {
      ocrWorkerPromise = Tesseract.createWorker('hin+eng', 1, {
        langPath: 'https://tessdata.projectnaptha.com/4.0.0',
        logger: () => {},
      });
    }
    return ocrWorkerPromise;
  }
  async function ocrPageWithWorker(page, worker) {
    const viewport = page.getViewport({ scale: 1.2 });
    const canvas = document.createElement('canvas');
    canvas.width = Math.ceil(viewport.width);
    canvas.height = Math.ceil(viewport.height);
    const ctx = canvas.getContext('2d', { willReadFrequently: true });
    if (!ctx) throw new Error('Could not create a canvas for OCR.');
    ctx.fillStyle = '#fff';
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    await page.render({ canvasContext: ctx, viewport }).promise;
    const result = await worker.recognize(canvas);
    const text = result.data.text || '';
    const words = (result.data.words || []).map(word => ({
      text: word.text || '',
      confidence: Math.round(word.confidence || 0),
      x0: word.bbox && word.bbox.x0 || 0,
      y0: word.bbox && word.bbox.y0 || 0,
      x1: word.bbox && word.bbox.x1 || 0,
      y1: word.bbox && word.bbox.y1 || 0,
    }));
    const deletedStampCandidates = words.filter(word =>
      /^(deleted|delet?ed|delete)$/i.test(word.text.replace(/[^a-zA-Z]/g, '')) &&
      word.confidence >= 20);
    return { text, words, deleted_stamp_candidates: deletedStampCandidates };
  }
  function imageObjectToDataUrl(img) {
    if (!img || !img.width || !img.height || !img.data) return null;
    const canvas = document.createElement('canvas');
    canvas.width = img.width; canvas.height = img.height;
    const ctx = canvas.getContext('2d');
    const out = ctx.createImageData(img.width, img.height);
    const src = img.data;
    // PDF.js ImageKind: 1=1-bit grayscale, 2=RGB, 3=RGBA.
    if (img.kind === 3 || src.length === img.width * img.height * 4) {
      out.data.set(src);
    } else if (img.kind === 2 || src.length === img.width * img.height * 3) {
      for (let s = 0, d = 0; s < src.length; s += 3, d += 4) {
        out.data[d] = src[s]; out.data[d + 1] = src[s + 1];
        out.data[d + 2] = src[s + 2]; out.data[d + 3] = 255;
      }
    } else if (img.kind === 1) {
      for (let i = 0; i < img.width * img.height; i++) {
        const bit = (src[i >> 3] >> (7 - (i & 7))) & 1;
        const value = bit ? 0 : 255, d = i * 4;
        out.data[d] = out.data[d + 1] = out.data[d + 2] = value; out.data[d + 3] = 255;
      }
    } else {
      return null;
    }
    ctx.putImageData(out, 0, 0);
    return canvas.toDataURL('image/jpeg', 0.88);
  }
  function getImage(page, id) {
    // PDF.js can leave an image object unresolved when a page contains a
    // damaged/unsupported image. Never let one image block the whole import.
    return new Promise(resolve => {
      let settled = false;
      const finish = value => {
        if (settled) return;
        settled = true;
        clearTimeout(timer);
        resolve(value || null);
      };
      const timer = setTimeout(() => finish(null), 8000);
      try {
        const existing = page.objs.get(id);
        if (existing) {
          finish(imageObjectToDataUrl(existing));
        } else {
          page.objs.get(id, value => {
            try { finish(imageObjectToDataUrl(value)); } catch (_) { finish(null); }
          });
        }
      } catch (_) {
        try {
          page.objs.get(id, value => {
            try { finish(imageObjectToDataUrl(value)); } catch (_) { finish(null); }
          });
        } catch (_) { finish(null); }
      }
    });
  }
  function isVoterChunk(text) {
    const value = String(text || '');
    const hasVoterId = /\b(?:[A-Z]{2,4}\d{6,10}|RJ\/\d{2}\/\d{3}\/\d{5,8})\b/i.test(value);
    const hasSerial = /(?:^|\s)E?\s*\d{1,4}(?:\s|$)/m.test(value);
    const hasFields = /नाम|नम|पिता|पति|आयु|लिंग|house|age|gender/i.test(value);
    return hasVoterId || (hasSerial && hasFields);
  }
  async function renderPageCanvas(page, scale) {
    const viewport = page.getViewport({ scale });
    const canvas = document.createElement('canvas');
    canvas.width = Math.ceil(viewport.width);
    canvas.height = Math.ceil(viewport.height);
    const ctx = canvas.getContext('2d', { willReadFrequently: true });
    if (!ctx) throw new Error('Could not create page canvas.');
    ctx.fillStyle = '#fff';
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    await page.render({ canvasContext: ctx, viewport }).promise;
    return canvas;
  }
  function cropCanvas(source, x, y, width, height) {
    const canvas = document.createElement('canvas');
    canvas.width = Math.max(1, Math.floor(width));
    canvas.height = Math.max(1, Math.floor(height));
    const ctx = canvas.getContext('2d', { willReadFrequently: true });
    if (!ctx) throw new Error('Could not create voter-card crop.');
    ctx.fillStyle = '#fff';
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.drawImage(source, x, y, width, height, 0, 0, canvas.width, canvas.height);
    return canvas;
  }
  function findRuleLines(canvas, axis, startRatio, endRatio, threshold) {
    const ctx = canvas.getContext('2d', { willReadFrequently: true });
    const width = canvas.width, height = canvas.height;
    const data = ctx.getImageData(0, 0, width, height).data;
    const horizontal = axis === 'horizontal';
    const length = horizontal ? width : height;
    const cross = horizontal ? height : width;
    const start = Math.floor(cross * startRatio);
    const end = Math.floor(cross * endRatio);
    const candidates = [];
    for (let pos = start; pos < end; pos++) {
      let dark = 0;
      // Sample every 2 pixels for speed; grid rules span a large proportion of the page.
      for (let i = 0; i < length; i += 2) {
        const x = horizontal ? i : pos;
        const y = horizontal ? pos : i;
        const idx = (y * width + x) * 4;
        const luminance = (data[idx] * 0.299) + (data[idx + 1] * 0.587) + (data[idx + 2] * 0.114);
        if (luminance < 105) dark++;
      }
      if (dark / Math.ceil(length / 2) >= threshold) candidates.push(pos);
    }
    const groups = [];
    for (const pos of candidates) {
      const last = groups[groups.length - 1];
      if (last && pos - last.end <= 3) {
        last.end = pos;
        last.sum += pos;
        last.count++;
      } else {
        groups.push({ start: pos, end: pos, sum: pos, count: 1 });
      }
    }
    return groups.map(g => Math.round(g.sum / g.count));
  }
  function findVerticalRulesInRegion(canvas, yStart, yEnd, threshold) {
    const ctx = canvas.getContext('2d', { willReadFrequently: true });
    const width = canvas.width;
    const data = ctx.getImageData(0, 0, width, canvas.height).data;
    const startY = Math.max(0, Math.floor(yStart));
    const endY = Math.min(canvas.height, Math.ceil(yEnd));
    const candidates = [];
    for (let x = Math.floor(width * 0.015); x < Math.ceil(width * 0.985); x++) {
      let dark = 0;
      let samples = 0;
      for (let y = startY; y < endY; y += 2) {
        const idx = (y * width + x) * 4;
        const luminance = data[idx] * 0.299 + data[idx + 1] * 0.587 + data[idx + 2] * 0.114;
        if (luminance < 105) dark++;
        samples++;
      }
      if (samples && dark / samples >= threshold) candidates.push(x);
    }
    const groups = [];
    for (const x of candidates) {
      const last = groups[groups.length - 1];
      if (last && x - last.end <= 3) {
        last.end = x; last.sum += x; last.count++;
      } else {
        groups.push({ start: x, end: x, sum: x, count: 1 });
      }
    }
    return groups.map(g => Math.round(g.sum / g.count));
  }
  function detectVoterGrid(canvas) {
    // Detect horizontal card rules first; use their extent to find vertical rules.
    const horizontal = findRuleLines(canvas, 'horizontal', 0.12, 0.97, 0.34);
    let rows = horizontal.filter(y => y / canvas.height >= 0.16);
    const gaps = rows.slice(1).map((y, i) => y - rows[i]);
    const sortedGaps = gaps.slice().sort((a, b) => a - b);
    const medianGap = sortedGaps.length ? sortedGaps[Math.floor(sortedGaps.length / 2)] : 0;
    // On the first voter page the header bottom rule is close to the first card row.
    if (gaps.length > 1 && medianGap > 0 && gaps[0] < medianGap * 0.45) rows = rows.slice(1);
    rows = rows.filter((y, i) => i === 0 || y - rows[i - 1] > canvas.height * 0.025);
    if (rows.length >= 3) {
      const vertical = findVerticalRulesInRegion(canvas, rows[0], rows[rows.length - 1], 0.48)
        .filter(x => x / canvas.width >= 0.02 && x / canvas.width <= 0.98);
      const left = vertical.find(x => x / canvas.width <= 0.12);
      const rightCandidates = vertical.filter(x => x / canvas.width >= 0.88);
      const right = rightCandidates.length ? rightCandidates[rightCandidates.length - 1] : null;
      if (left != null && right != null && right - left > canvas.width * 0.65) {
        const span = right - left;
        const target1 = left + span / 3;
        const target2 = left + span * 2 / 3;
        const interior = vertical.filter(x => x > left + span * 0.18 && x < right - span * 0.18);
        const nearest = target => interior.reduce((best, x) =>
          best == null || Math.abs(x - target) < Math.abs(best - target) ? x : best, null);
        const middle1 = nearest(target1);
        const middle2 = nearest(target2);
        if (middle1 != null && middle2 != null && middle1 < middle2) {
          return { xBounds: [left, middle1, middle2, right], yBounds: rows, detected: true };
        }
      }
    }
    return null;
  }
  async function parseChunk(pageCanvas, pageNo, row, col, worker, grid) {
    const x0 = grid.xBounds[col], x1 = grid.xBounds[col + 1];
    const y0 = grid.yBounds[row], y1 = grid.yBounds[row + 1];
    const crop = cropCanvas(pageCanvas, x0, y0, x1 - x0, y1 - y0);
    const result = await worker.recognize(crop);
    const text = (result.data.text || '').trim();
    const words = (result.data.words || []).map(word => ({
      text: word.text || '',
      confidence: Math.round(word.confidence || 0),
      x0: word.bbox && word.bbox.x0 || 0,
      y0: word.bbox && word.bbox.y0 || 0,
      x1: word.bbox && word.bbox.x1 || 0,
      y1: word.bbox && word.bbox.y1 || 0
    }));
    const valid = isVoterChunk(text);
    const deletedStamp = /\\bDELETED\\b/i.test(text) || words.some(w => /^(deleted|delete)$/i.test(w.text));
    const voterIdMatch = text.match(/\\b(?:[A-Z]{2,4}\\d{6,10}|RJ\\/\\d{2}\\/\\d{3}\\/\\d{5,8})\\b/i);
    return {
      page: pageNo, grid_row: row + 1, grid_column: col + 1,
      chunk_id: 'p' + pageNo + '-r' + (row + 1) + '-c' + (col + 1),
      grid_detected: grid.detected,
      text, confidence: words.length ? Math.round(words.reduce((n, w) => n + w.confidence, 0) / words.length) : 0,
      valid_voter_candidate: valid, voter_id_candidate: voterIdMatch ? voterIdMatch[0] : null,
      deleted_stamp_candidate: deletedStamp,
      needs_review: !valid || deletedStamp || words.some(w => w.confidence < 55),
      chunk_image_data_url: valid ? crop.toDataURL('image/jpeg', 0.72) : null
    };
  }
  async function extractImages(base64, filename) {
    const pdfjs = await loadPdfJs();
    const binary = atob(base64);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
    const pdf = await pdfjs.getDocument({ data: bytes }).promise;
    const pages = [];
    const workers = [];
    try {
      const Tesseract = await Promise.race([
        loadTesseract(),
        new Promise((_, reject) => setTimeout(() => reject(new Error('OCR library load timed out after 45 seconds. Check internet and retry.')), 45000))
      ]);
      // Three real Tesseract worker threads balance throughput and browser memory.
      await Promise.all([0, 1, 2].map(async () => {
        const worker = await Promise.race([
          Tesseract.createWorker('hin+eng', 1, {
            langPath: 'https://tessdata.projectnaptha.com/4.0.0',
            logger: () => {}
          }),
          new Promise((_, reject) => setTimeout(() => reject(new Error('Hindi OCR worker startup timed out.')), 45000))
        ]);
        workers.push(worker);
      }));
      let taskIndex = 0;
      for (let pageNo = 1; pageNo <= pdf.numPages; pageNo++) {
        await new Promise(resolve => setTimeout(resolve, 0));
        const page = await pdf.getPage(pageNo);
        const textContent = await page.getTextContent();
        const embeddedText = textContent.items.map(item => item.str || '').join(' ').replace(/\\s+/g, ' ').trim();
        let pageCanvas;
        try {
          pageCanvas = await renderPageCanvas(page, 1.5);
          // The sample has two cover/map pages, followed by 3-column x 9-row
          // voter-card grids. Keep cover pages as whole-page OCR.
          if (pageNo <= 2) {
            const result = await workers[taskIndex++ % workers.length].recognize(pageCanvas);
            const text = result.data.text || embeddedText;
            pages.push({ page: pageNo, text, embedded_text: embeddedText, ocr_text: result.data.text || '', chunk_count: 0, chunks: [], images: [] });
          } else {
            const chunks = [];
            const jobs = [];
            const grid = detectVoterGrid(pageCanvas);
            if (!grid) {
              const result = await workers[taskIndex++ % workers.length].recognize(pageCanvas);
              pages.push({
                page: pageNo, text: result.data.text || embeddedText,
                embedded_text: embeddedText, ocr_text: result.data.text || '',
                grid_detection_failed: true, chunk_count: 0,
                valid_voter_chunk_count: 0, chunks: [], images: []
              });
            } else {
              const rowCount = Math.max(0, grid.yBounds.length - 1);
              const colCount = Math.max(0, grid.xBounds.length - 1);
              const chunks = [];
              const jobs = [];
              for (let row = 0; row < rowCount; row++) {
                for (let col = 0; col < colCount; col++) {
                  const worker = workers[taskIndex++ % workers.length];
                  jobs.push(parseChunk(pageCanvas, pageNo, row, col, worker, grid).then(chunk => {
                    chunks.push(chunk);
                  }).catch(error => {
                    chunks.push({ page: pageNo, grid_row: row + 1, grid_column: col + 1,
                      chunk_id: 'p' + pageNo + '-r' + (row + 1) + '-c' + (col + 1),
                      text: '', valid_voter_candidate: false, needs_review: true, error: String(error) });
                  }));
                }
              }
              await Promise.all(jobs);
              chunks.sort((a, b) => (a.grid_row - b.grid_row) || (a.grid_column - b.grid_column));
              const validChunks = chunks.filter(chunk => chunk.valid_voter_candidate);
              pages.push({
                page: pageNo,
                text: validChunks.map(chunk => chunk.text).join('\\n'),
                embedded_text: embeddedText,
                ocr_text: chunks.map(chunk => chunk.text).join('\\n'),
                grid_detected: true,
                chunk_count: chunks.length,
                valid_voter_chunk_count: validChunks.length,
                chunks,
                images: []
              });
            }
          }
        } finally {
          if (pageCanvas) { pageCanvas.width = 1; pageCanvas.height = 1; }
        }
      }
    } finally {
      await Promise.all(workers.map(async worker => {
        try { await worker.terminate(); } catch (_) {}
      }));
    }
    const chunkCount = pages.reduce((sum, page) => sum + (page.chunk_count || 0), 0);
    const validCount = pages.reduce((sum, page) => sum + (page.valid_voter_chunk_count || 0), 0);
    return JSON.stringify({ filename, page_count: pdf.numPages, image_count: 0, chunk_count: chunkCount, valid_voter_chunk_count: validCount, pages });
  }
  window.gagwanaPdfImages = { extractImages };
})();