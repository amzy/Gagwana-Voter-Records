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
    let totalImages = 0;
    for (let pageNo = 1; pageNo <= pdf.numPages; pageNo++) {
      // Yield to the browser between pages so large voter rolls stay responsive.
      await new Promise(resolve => setTimeout(resolve, 0));
      const page = await pdf.getPage(pageNo);
      const textContent = await page.getTextContent();
      const text = textContent.items.map(item => item.str || '').join(' ').replace(/\s+/g, ' ').trim();
      const ops = await page.getOperatorList();
      const imageIds = [];
      const seen = new Set();
      for (let i = 0; i < ops.fnArray.length; i++) {
        const fn = ops.fnArray[i], args = ops.argsArray[i];
        if ((fn === pdfjs.OPS.paintImageXObject || fn === pdfjs.OPS.paintImageMaskXObject) &&
            args && typeof args[0] === 'string' && !seen.has(args[0])) {
          seen.add(args[0]); imageIds.push(args[0]);
        } else if (fn === pdfjs.OPS.paintInlineImageXObject && args && args[0]) {
          const url = imageObjectToDataUrl(args[0]);
          if (url) { imageIds.push({ inline: url }); }
        }
      }
      const images = [];
      for (let i = 0; i < imageIds.length; i++) {
        const entry = imageIds[i];
        const dataUrl = typeof entry === 'string' ? await getImage(page, entry) : entry.inline;
        if (dataUrl) images.push({ index: images.length + 1, data_url: dataUrl });
      }
      totalImages += images.length;
      pages.push({ page: pageNo, text, images });
    }
    return JSON.stringify({ filename, page_count: pdf.numPages, image_count: totalImages, pages });
  }
  window.gagwanaPdfImages = { extractImages };
})();