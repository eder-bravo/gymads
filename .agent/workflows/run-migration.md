---
description: Run a Supabase SQL migration against the remote database
---

# Run Supabase Migration

This workflow runs a SQL migration file against the remote Supabase database using the Management API.

## Prerequisites
- The `.env` file must contain:
  - `SUPABASE_ACCESS_TOKEN` — from supabase.com/dashboard/account/tokens
  - `SUPABASE_URL` — project URL (used to extract project ref)

## Steps

// turbo-all

1. Read the migration SQL file content
2. Run it using the Supabase Management API:

```bash
SQL=$(cat "<path-to-migration-file>") && \
curl -s -X POST "https://api.supabase.com/v1/projects/<project-ref>/database/query" \
  -H "Authorization: Bearer <SUPABASE_ACCESS_TOKEN>" \
  -H "Content-Type: application/json" \
  -d "{\"query\": $(echo "$SQL" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')}"
```

- Replace `<path-to-migration-file>` with the absolute path to the `.sql` file.
- Replace `<project-ref>` with the Supabase project ref (extracted from SUPABASE_URL: the subdomain before `.supabase.co`).
- Replace `<SUPABASE_ACCESS_TOKEN>` with the token from `.env`.

3. Verify the response:
   - `[]` = success (no rows returned, DDL executed)
   - Any JSON with `"error"` = failure, read the message

## Notes
- Direct DB connections (`db push`) time out from this network, so we use the Management API.
- The project ref for this project is: `olhbhnjhducfxkffercu`
- The access token is in `.env` as `SUPABASE_ACCESS_TOKEN`
