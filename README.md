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
flutter run -d chrome
```

## GitHub Pages
The workflow at `.github/workflows/deploy-pages.yml` builds the Flutter web app and deploys it when changes are pushed to `main` (including a pull request merge). Pull requests targeting `main` run the build but do not publish.

In GitHub, open **Settings → Pages** and set **Build and deployment → Source** to **GitHub Actions**. The published site will be available at:

https://amzy.github.io/Gagwana-Voter-Records/

## Important implementation status
This is a UI starter with demonstration voter records. The PDF picker selects a file, but actual Hindi OCR, voter-photo extraction, Google Sheets synchronization, import preview, and persistence are not implemented yet.

For production, process PDFs on a secured backend (Firebase Cloud Functions or Cloud Run), use Hindi Devanagari OCR and confidence-based review, extract images with source-page references, detect only explicit DELETED marks, and show a preview before updating records. Keep Google service-account credentials on the server, protect import/review with admin authentication, and maintain an audit log. Do not infer that a voter is deleted merely because they are absent from a later PDF.
