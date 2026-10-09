# Integration capabilities

| Source | Current behavior | Boundary |
|---|---|---|
| The Piece | Live user-scoped draft discovery and metadata refresh | Own records only; never writes drafts |
| One Great Paragraph drafts | Live discovery | Current app resumes today's draft only; older records link to app home |
| One Great Paragraph library | Live deliberate selection | Saved paragraphs are not unfinished work |
| Idea Garden ideas | Live deliberate selection | Local project assemblies require manual linking |
| Bible Margins | Live deliberate note selection | Scripture notes remain in Bible Margins |
| The Study | Live deliberate study selection | Resources and documents remain in The Study |
| The Book | `_book.json` metadata import | No manuscript content transfer or cross-origin device access |
| Things of the Sort | Content JSON metadata import and publication links | Snapshot only; no live private scheduling bridge or publishing action |
| Open Loop | Manual commitment links | Separate Supabase/auth boundary; no write-back |
| Other research apps | Typed manual source links | No background ingestion of private or pastoral records |

Successful refreshes upsert by `(user_id,source,source_id)` and preserve discovery decisions and project planning. Source disappearance marks a record unavailable; it never completes or deletes desk work. Failed refreshes retain all records. Source status changes appear for project review rather than overwriting deliberate desk stages.

The source providers are read through SECURITY INVOKER functions, source RLS, and explicit owner predicates. Different source identities may return an empty list; the desk does not map accounts by email or claim ownership.

The public-schema `writingdesk_*` functions are a narrow transport over the isolated, non-exposed `writingdesk` schema. They use caller privileges, enforce current Gathered Pages membership, revoke anon/PUBLIC execution, and do not change the shared exposed-schema list.
