# Published voter database

The app's **Sync latest database** action downloads this fixed file from the `main` branch:

`data/gagwana_voter_records.db`

Replace that binary file with the newly finalized SQLite database when records/photos are updated. Keep the exact filename and path so the app's sync URL remains stable. The database must contain a `voters` table and a `photo_blob` BLOB column. The app validates the file before replacing its browser-local database.

The SQLite database itself is intentionally not represented by this README; upload the finalized `.db` binary at the path above.