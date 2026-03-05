# Command OS — WORKPLAN (v1 Build Checklist)

This is the step-by-step execution plan for building Command OS v1 reliably.

Principle: ship a tiny end-to-end loop first:
Admin Web → create task → Worker leases → Worker runs capability → artifacts/events stored → Admin sees results.

## Definitions
- Done = acceptance criteria satisfied.
- Always commit small increments.
- No secrets in repo. Use local `.env` and Supabase secrets.

## Milestone 0 — Repo Foundation (Day 0)
Goal: repository structure + rules that prevent chaos.

Tasks
1) Create repo layout
- Create folders:
  - apps/admin-web
  - services/worker-agent
  - services/capabilities
  - supabase/sql
  - supabase/functions
  - docs/runbooks
  - docs/policies

2) Add `.gitignore`
Must include:
- .env, .env.*, *.local, node_modules, dist, build, logs, secrets

3) Add `docs/ARCHITECTURE.md` (master architecture file)

Acceptance criteria
- Repo has correct folder structure
- `.gitignore` prevents env/secrets
- Architecture file exists and matches system intent

Deliverables
- Commit: "Repo foundation + architecture"

---

## Milestone 1 — Supabase Project + Schema (Day 1)
Goal: backend tables exist with RLS enabled and storage buckets created.

Tasks
1) Create Supabase project
2) Create SQL files:
- `supabase/sql/001_schema.sql`
- `supabase/sql/002_rls.sql`

Minimum tables (v1):
- devices
- tasks
- events
- artifacts
- approvals (can be minimal but present)

3) Enable pgcrypto extension if needed for UUID defaults.
4) Apply schema and RLS using Supabase SQL Editor.

5) Create Storage buckets (private):
- artifacts
- logbundles
- datasets
- quarantine

Acceptance criteria
- Tables exist and RLS is enabled
- Buckets exist and are private
- You can insert/read your own records via Auth + RLS (from admin-web later)

Deliverables
- Commit: "Supabase schema + RLS + bucket plan"

---

## Milestone 2 — Edge Functions Gateway (Day 2–3)
Goal: workers and UI interact through Edge Functions for the core loop.

Required Edge Functions (v1)
1) device-heartbeat
2) task-lease
3) task-start
4) task-step
5) task-complete
6) artifact-create-upload
7) artifact-confirm-upload
8) policy-halt

Rules
- Use service_role key ONLY in edge functions.
- Add audit event for every mutation.
- Enforce: device must own lease to start/step/complete or upload artifacts.
- Heartbeat can be summarized (still emits device.heartbeat event).

Acceptance criteria
- Each function deployed successfully
- Basic curl tests succeed
- lease is atomic (no double claim)

Deliverables
- Commit: "Edge gateway v1 endpoints"

---

## Milestone 3 — Worker Agent v0 (Day 3–5)
Goal: HP/ASUS can run a worker that heartbeats + leases tasks + executes one capability.

Tasks
1) Create Node/TypeScript worker project in `services/worker-agent`.
2) Implement config loader:
- reads local file (NOT committed): `config/worker.<device>.local.json`

3) Implement gateway client:
- heartbeat
- lease
- start
- step
- complete
- artifact upload flow

4) Implement one capability:
- `system.healthcheck`
Outputs:
- logbundle (zip) with system stats and a text report

5) Implement safe stop:
- checks halt flag on heartbeat responses
- stops leasing new tasks when halted

Acceptance criteria
- Worker can heartbeat (device seen in DB)
- Worker can lease a queued task and execute it
- Worker uploads a logbundle artifact
- Task marked succeeded and events show full timeline

Deliverables
- Commit: "Worker agent v0 + healthcheck capability"

---

## Milestone 4 — Admin Web Console v0 (Day 5–7)
Goal: a simple web UI to control v1 without needing Android yet.

Pages (minimum)
- /login
- /devices (list last seen, status)
- /tasks (create task, list tasks)
- /artifacts (list artifacts, open signed URL)
- /events (timeline view with filters)

Rules
- Uses Supabase anon key + Auth user login
- No service_role secrets in the client
- Fetch signed URLs via edge function if needed

Acceptance criteria
- You can log in
- You can create healthcheck tasks
- You can see them run and complete
- You can open the logbundle artifact
- Events show who/what/when

Deliverables
- Commit: "Admin web v0 console"

---

## Milestone 5 — Reliability + Drills (Day 7–10)
Goal: the system can recover from normal failures and you can stop it quickly.

Tasks
1) Lease expiry behavior:
- simulate worker crash mid-task
- verify task returns to queued or is recoverable

2) Kill switch drill:
- set global halt flag
- worker stops leasing within 30 seconds

3) Artifact retention:
- intermediates expire
- logbundles expire
- finals persist

4) Incident bundle:
- worker can produce diagnostic bundle on demand

Acceptance criteria
- One successful kill-switch drill
- One successful crash recovery drill
- Retention rules validated

Deliverables
- Commit: "Reliability drills + retention"

---

## Milestone 6 — v1 Release (Day 10+)
Goal: stable v1 you can run daily.

Release checklist
- Go-live gate passed (docs/runbooks)
- Backup strategy chosen
- Device revoke runbook tested
- Updates require approval (even if manual for v1)

Deliverables
- Tag release: v1.0.0
