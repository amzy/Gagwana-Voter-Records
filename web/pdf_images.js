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
  async function extractImages(base64, filename) {
    const pdfjs = await loadPdfJs();
    const binary = atob(base64);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
    const pdf = await pdfjs.getDocument({ data: bytes }).promise;
    const pages = [];
    let worker = null;
    try {
      // OCR is the priority. Do not extract every embedded face image here:
      // that can block for seconds per unresolved PDF.js image object.
      worker = await Promise.race([
        getOcrWorker(),
        new Promise((_, reject) => setTimeout(() => reject(new Error('Hindi OCR engine took too long to start. Reload and retry; check the network connection.')), 45000))
      ]);
      for (let pageNo = 1; pageNo <= pdf.numPages; pageNo++) {
        await new Promise(resolve => setTimeout(resolve, 0));
        const page = await pdf.getPage(pageNo);
        const textContent = await page.getTextContent();
        const embeddedText = textContent.items.map(item => item.str || '').join(' ').replace(/\\s+/g, ' ').trim();
        let ocr = { text: '', words: [], deleted_stamp_candidates: [], error: null };
        try {
          ocr = await Promise.race([
            ocrPageWithWorker(page, worker),
            new Promise((_, reject) => setTimeout(() => reject(new Error('OCR timed out on page ' + pageNo)), 30000))
          ]);
        } catch (error) {
          ocr.error = String(error && error.message || error);
        }
        const text = ocr.text || embeddedText;
        pages.push({
          page: pageNo,
          text,
          embedded_text: embeddedText,
          ocr_text: ocr.text,
          ocr_words: ocr.words,
          deleted_stamp_candidates: ocr.deleted_stamp_candidates,
          ocr_error: ocr.error || null,
          images: []
        });
      }
    } finally {
      if (ocrWorkerPromise) {
        try { await (await ocrWorkerPromise).terminate(); } catch (_) {}
        ocrWorkerPromise = null;
      }
    }
    return JSON.stringify({ filename, page_count: pdf.numPages, image_count: 0, pages });
  }
  window.gagwanaPdfImages = { extractImages };
})();