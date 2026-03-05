# Command OS — COPILOT / GITHUB AI PROMPTS (Scripted)

These prompts are designed to be pasted into GitHub Copilot Chat or a code agent.
Use them IN ORDER. Do not skip ahead.

General rules for the code agent
- Create one file at a time.
- Keep changes small and testable.
- Do not add dependencies unless requested.
- Never put secrets in repo.
- Prefer explicit types and simple code over clever code.

----------------------------------------------------------------
PHASE 0 — Repo foundation
----------------------------------------------------------------

Prompt 0.1
"Create a `.gitignore` in the repo root suitable for a Node/Next.js + Supabase + TypeScript monorepo. Must ignore env files, node_modules, build output, logs, and config/*.local.json."

Prompt 0.2
"Create the folder structure described in docs/ARCHITECTURE.md. Add placeholder README.md files in each top-level folder explaining purpose (apps/, services/, supabase/, docs/)."

----------------------------------------------------------------
PHASE 1 — Supabase SQL (schema + RLS)
----------------------------------------------------------------

Prompt 1.1
"Create `supabase/sql/001_schema.sql` implementing v1 tables:
- devices
- tasks
- approvals
- events
- artifacts
Use UUID PKs. Include created_at/updated_at. Include task leasing fields (lease_owner_device_id, lease_expires_at, attempt_count). Include artifacts fields (bucket, path, sha256, size_bytes, content_type, retention). Include events fields (event_type, actor_type user/device, actor_id, task_id, artifact_id, payload jsonb)."

Prompt 1.2
"Create `supabase/sql/002_rls.sql` enabling RLS and owner-scoped policies for all v1 tables. Use auth.uid() as owner_user_id. Ensure:
- users can CRUD their own devices/tasks/artifacts/approvals
- events are insertable by service role only OR by owner via edge functions (pick a consistent approach and document it in comments)
- tasks leasing updates are performed by edge functions using service role."

Note: For simplicity in v1, have edge functions write events using service_role, and make events read-only to users via RLS.

----------------------------------------------------------------
PHASE 2 — Edge Functions (gateway)
----------------------------------------------------------------

Prompt 2.1 (shared utility)
"Create `supabase/functions/_shared/supa.ts` that initializes a Supabase client with service role using environment variables SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY. Use Deno-compatible imports."

Prompt 2.2 (heartbeat)
"Create `supabase/functions/device-heartbeat/index.ts`:
- parse JSON {device_id, agent_version, health}
- verify device exists and is active (skip signature verification for now but leave a TODO)
- update devices.last_seen_at and devices.agent_version
- insert an event row event_type='device.heartbeat' with payload health
- respond {ok:true, halt:false, time:<iso>}."

Prompt 2.3 (task lease)
"Create `supabase/functions/task-lease/index.ts`:
Input {device_id, capabilities: string[], max_claim}
Behavior:
- find one queued task matching owner_user_id for that device (join devices table)
- require capability_name in capabilities
- require approvals_satisfied=true (for v1, treat approvals_required empty as satisfied)
- atomically set status='leased', lease_owner_device_id=device_id, lease_expires_at=now()+600s, attempt_count=attempt_count+1
- insert event task.leased
Return task payload or null."

Prompt 2.4 (task start/step/complete)
"Create edge functions task-start, task-step, task-complete that:
- validate task is leased by device_id
- start: status leased->running, insert event task.started
- step: insert event task.step with payload and basic rate limit comment
- complete: set status succeeded/failed, insert event task.completed with artifact_ids
Return ok."

Prompt 2.5 (artifact upload)
"Create `artifact-create-upload` and `artifact-confirm-upload`:
- validate task leased by device
- create artifacts row
- generate signed upload URL for bucket/path
- confirm upload marks artifact confirmed.
Document how worker uses it."

Prompt 2.6 (halt)
"Create `policy-halt` function:
- requires user auth (Supabase JWT) OR service role only (choose one; document)
- sets a global halt flag in a settings table OR updates devices.halt=true for all devices
- returns ok.
If no settings table exists, add one in schema and update RLS."

----------------------------------------------------------------
PHASE 3 — Worker agent (Node + TypeScript)
----------------------------------------------------------------

Prompt 3.1
"Create `services/worker-agent/package.json` and tsconfig for a small Node TypeScript service. Use minimal dependencies: node-fetch (or native fetch), zod, archiver (for zipping), and winston (optional). Provide npm scripts: dev, build, start."

Prompt 3.2
"Create `services/worker-agent/src/config.ts` that loads JSON config from a path specified in env WORKER_CONFIG_PATH. Validate shape with zod."

Prompt 3.3
"Create `services/worker-agent/src/gateway.ts` client with methods:
heartbeat(), leaseTask(), startTask(), stepTask(), completeTask(), createUpload(), confirmUpload().
All call the deployed Supabase function URLs."

Prompt 3.4
"Create `services/worker-agent/src/capabilities/system.healthcheck.ts` that gathers:
- OS platform, release
- CPU count
- total/free memory
- disk free for C:
Write a report.txt in task workdir."

Prompt 3.5
"Create `services/worker-agent/src/artifacts.ts` to zip a folder to a file, compute sha256, then call createUpload() to get signed URL and PUT upload the zip, then confirmUpload()."

Prompt 3.6
"Create `services/worker-agent/src/main.ts`:
- loops forever every 15s
- heartbeat
- if not halted: leaseTask
- if task returned:
  - startTask
  - dispatch to capability handler (only system.healthcheck for v1)
  - zip logs, upload logbundle artifact
  - completeTask succeeded
- handle errors: complete failed and emit step message."

----------------------------------------------------------------
PHASE 4 — Admin web (Next.js)
----------------------------------------------------------------

Prompt 4.1
"Create a Next.js app in `apps/admin-web` with Supabase Auth login. Provide pages:
- /login
- /devices
- /tasks (create task form + list)
- /artifacts
- /events
Keep UI simple. Use Tailwind. No advanced component libs."

Prompt 4.2
"Implement create task:
insert row into tasks table with capability_name='system.healthcheck', status='queued', risk='low'.
Add target_device_id optional field if schema supports it."

Prompt 4.3
"Artifacts page: list artifacts and include a button that calls an edge function (to be created later) to generate a signed download URL for viewing."

----------------------------------------------------------------
PHASE 5 — Tests + drills
----------------------------------------------------------------

Prompt 5.1
"Add a simple integration test script in `tools/test-e2e.ps1` that:
- creates a healthcheck task
- waits for status succeeded
- fetches artifacts list and prints the latest logbundle path."

Prompt 5.2
"Add a kill-switch drill script that sets halt=true then verifies worker stops leasing new tasks."
