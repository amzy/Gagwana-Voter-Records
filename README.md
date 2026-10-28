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

## Local SQLite storage

The Flutter web app loads SQLite WebAssembly in the browser. Its database is persisted in browser IndexedDB, so no Python API or local server is required after deploying the static app. The app can export a `voter_records.db` backup and import a compatible `.db` file on another browser/device.

**Storage scope:** browser-local data is not automatically shared between devices and can be cleared by browser site-data cleanup. Export backups regularly. The first load needs internet access to load the SQL.js WebAssembly library from CDN.

**PDF import status:** selecting PDFs is supported, but browser-side PDF text extraction, Hindi OCR, structured voter-row parsing, photo extraction, duplicate-aware merge, and review-before-save are not yet implemented. The local database currently provides the storage and backup foundation only. The existing search screen still uses demonstration records until it is connected to SQL queries.
