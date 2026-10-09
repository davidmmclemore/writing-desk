# The Writing Desk

A private writing planning workspace for The Gathered Pages. Drafts stay in their original apps; the desk gathers next steps, deadlines, research links, and publication plans.

## Included

- Warm paper / evening ink interface, responsive on desktop and mobile.
- Desk, all writing, possibilities, commitments, Inbox, calendar, series, finished shelf, weekly review, connections, and settings.
- Project stages, focus, next actions, deadlines, publication plans, waiting, pauses, priorities, series ordering, tasks, rich-text planning notes, and reflection.
- Live discovery for The Piece and paragraph drafts; deliberate source selection for saved paragraphs, Idea Garden, Bible Margins, and The Study.
- Book metadata import; site-content JSON import; typed manual links for the remaining apps.
- Version-checked project/series/task saves, current membership enforcement, owner RLS, JSON export, installable manifest, and a public-only offline shell.

## Setup

Use Node 24. `npm ci`, then `npm run dev`.

The public project URL and publishable key have safe defaults in `lib/config.ts`. Override them with `.env.local` when needed. No service-role key or publishing secret is used. Copy `.env.example` for the variable names.

Sign in with an existing confirmed, approved Gathered Pages email/password account. No new signup or shared Auth settings changes are made.

The database migration is in `supabase/migrations/001_writingdesk.sql`. It has been applied to the Gathered Pages project `zfhbetdwmbvuuvwqmnqu`. All application tables live in the isolated `writingdesk` schema; public invoker RPCs provide the Data API transport without changing shared API exposure settings.

## Checks

```
npm run typecheck
npm test
npm run build
npm run start -- --hostname 127.0.0.1
```

Database regression checks in `tests/database.sql` create throwaway identities inside a transaction and roll everything back. Run using the SQL editor or a trusted database connection.

Authenticated runtime verification: provision an approved throwaway account, write its email/password to a private JSON file, then run `QA_ACCOUNT_FILE=/path/to/account.json node tests/session-smoke.mjs` after the production build. The check exercises actual sign-in, project saves, conflict rejection, all six source readers, server rendering, export, and deletion. It logs no credentials. Delete the throwaway account and its test data after the check.

## Vercel

Existing project: `writing-desk`, team `david-mclemores-projects`. Framework: Next.js; Node: 24; build command: `npm run build`. The project is connected to `davidmmclemore/writing-desk`.

## Privacy and limitations

Data routes recheck authenticated identity and active membership on every request. Tables independently enforce ownership and membership. Private data has no shared cache and is never cached by the service worker. Explicit saves retain the editor after failures and reject stale versions rather than overwriting another tab.

Online access is required to save. There is no offline edit queue or browser recovery cache. External publication is not triggered by calendar entries. See [integration capabilities](docs/INTEGRATIONS.md) for supported connections and actual boundaries.
