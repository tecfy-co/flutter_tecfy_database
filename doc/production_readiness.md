# Production Readiness Guide

## Database size
SQLite comfortably handles millions of rows. Keep large binary blobs out of the
JSON body where possible; store them on disk and keep a path/reference instead.

## Indexing best practices
- Index only the fields you actually filter, sort, or group by. Each index adds
  write cost and storage.
- Use composite indexes for queries that always filter/sort on the same field
  combination.
- Remember non-indexed fields are not queryable — they live only in the JSON body.

## Backups
The database is a single SQLite file. To back up, ensure writes are flushed
(`await db.isReady()` and avoid in-flight batches), then copy the file from the
app documents/databases directory. Restore by replacing the file before opening
the database.

## Migrations
Index/schema changes are reconciled automatically on startup from your
`TecfyCollection` declarations. Adding/removing index fields preserves document
data; changing a primary key drops the table — migrate that data manually.

## Performance considerations
- Prefer `getBatch()` + `commitBatch()` for bulk writes (atomic, one notification).
- Only set `notify`/`notifier` when a live stream must refresh.
- Use `searchAny`/`searchCount` instead of fetching full lists when you only need
  existence or counts.
- Datetime filter values must be passed as epoch integers (see README
  Troubleshooting).
