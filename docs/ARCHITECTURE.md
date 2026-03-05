# Command OS — Master Architecture (v1 → v3)

## 0) Purpose
Command OS is a phone-first control plane that orchestrates two worker laptops (HP + ASUS) to execute tasks (builds, scans, media generation, knowledge ingestion) while maintaining strict approvals, audit logs, and least-privilege security.

Core goals:
- Phone provides the command surface: tasks, approvals, alerts, timeline.
- Workers execute long-running jobs in a sandbox (prefer containers).
- Backend provides system-of-record: devices, tasks, events, artifacts, knowledge.
- Deny-by-default posture: nothing runs without explicit enrollment and approval.

Non-goals (v1):
- No autonomous “remote shell” or freeform remote control.
- No silent calendar edits; only propose → approve → commit.
- No always-listening or continuous recording by default (must be opt-in, explicit, and reversible).

## 1) Roles and Responsibilities

### Control Plane (Phone)
- Shows device status, task queue, approvals, alerts, audit timeline.
- Creates tasks and approves risky actions.
- Reads artifacts via signed links.
- Stores minimal local cache for offline viewing.

### Worker Plane (HP + ASUS)
- Runs a Worker Agent service that:
  - heartbeats health metrics
  - leases tasks
  - executes capability modules (sandboxed)
  - uploads artifacts
  - emits structured events
  - obeys halt/kill-switch flags
- HP is primary compute and scan station; ASUS is secondary/light worker + dev.

### Backend (Supabase)
- Postgres tables: devices, tasks, approvals, events, artifacts, knowledge docs/chunks.
- Storage buckets: artifacts, logbundles, datasets, quarantine, releases (optional).
- Edge Functions act as a gateway enforcing authorization and device identity.
- RLS enabled for all exposed tables; workers do not hold service_role keys.

## 2) System Data Model (high level)
Core entities:
- Device: enrolled node (phone/worker), status, tags, last seen, versions.
- Capability: module executable by workers, with strict manifest contract.
- Task: requested capability + inputs + required approvals, status, leasing.
- Approval: human gating record for risky scopes or commits.
- Event: append-only audit ledger of actions and execution.
- Artifact: outputs stored in Storage, content hash, metadata, retention.
- KnowledgeDoc/Chunk: ingestion and retrieval storage with provenance.

## 3) Architecture Pattern
Pattern: “Gateway-first”
- Workers call Edge Functions (gateway) using device-auth signatures.
- Edge Functions write to DB and issue signed upload/download URLs for Storage.
- Phone and Admin UI use Supabase Auth user tokens (anon key) + RLS.

Rationale:
- Workers never get high-power credentials.
- Authorization is centralized and testable.
- Audit logging is consistent.

## 4) Task Lifecycle (state machine)
Task states:
- queued → leased → running → succeeded/failed/canceled/expired
Leasing rules:
- Lease is atomic and time-bound.
- Only the lease-owner device may start/step/complete.
- If lease expires, task can return to queue (or marked expired) with audit event.
Idempotency:
- Each task has an idempotency_key; retries must not duplicate irreversible effects.

## 5) Capability Contract (mandatory)
Each capability ships a manifest defining:
- name, version, display_name, risk_default
- input schema and limits
- outputs (artifact types, size limits, retention)
- permissions (db read/write, storage read/write, network allowlist, device scopes)
- resource limits (runtime, memory, cpu, disk)
- logging requirements (start/step/complete/failed)
- safety rules (destructive actions require approval + rollback plan)
- contract tests required

Default rules:
- network is deny by default
- removable media access denied by default
- filesystem access limited to task workdir + explicitly allowed datasets

## 6) Security Model
- Enrollment: devices must be enrolled by the owner; unknown devices rejected.
- Device auth: signed requests with nonce + timestamp replay protection.
- User auth: Supabase Auth JWT, RLS for owner-scoped data.
- Least privilege: deny-by-default network posture and explicit scope manifests.
- Audit: append-only events for every action; no secrets in logs/events.
- Kill switch:
  - soft halt: stop leasing + checkpoint stop
  - hard lockdown: revoke device + deny tailnet paths (if used)

## 7) Interfaces (APIs)
Edge Function endpoints (v1):
- POST /device/heartbeat
- POST /task/lease
- POST /task/start
- POST /task/step
- POST /task/complete
- POST /artifact/create-upload
- POST /artifact/confirm-upload
- POST /policy/halt

Planned (v1.5+):
- POST /calendar/propose
- POST /calendar/commit (requires approval)
- POST /release/register (signed releases)
- POST /memory/ingest (create ingestion tasks)

## 8) v1 Deliverables (minimum shippable)
Backend:
- schema + RLS
- storage buckets private
- Edge Functions for heartbeat + leasing + artifacts
Workers:
- agent that heartbeats + leases
- one capability: system.healthcheck
- uploads logbundle artifact
Admin console (web first):
- devices list + status
- tasks list + create healthcheck task
- artifacts list

## 9) v2 Deliverables (expansion)
- approvals UX and enforcement
- doc.generate + image.generate
- knowledge ingestion + retrieval (pgvector)
- incident bundles + rollback drills
- phone-native UI (Android) and push notifications

## 10) v3 Deliverables (heavy media)
Video:
- video.render_from_images (pipeline starter)
- video.generate (heavier; may require GPU and long runtimes)
3D:
- model3d.convert (OBJ/GLB/STL conversions)
- model3d.generate (asset generation)
- environment.package (scene bundling + metadata)
- environment.generate (long-running jobs; checkpoint required)

Rules for heavy media:
- must support checkpoints
- strict resource envelopes
- artifact retention and quota enforcement
- HP-only unless ASUS upgraded

## 11) Repo Layout (target)
apps/
  admin-web/                # web console (v1)
  command-os-android/        # android app (v2)
services/
  worker-agent/              # agent service (v1)
  capabilities/
    system.healthcheck/
    doc.generate/
    image.generate/
    video.render_from_images/
    video.generate/
    model3d.convert/
    model3d.generate/
    environment.package/
    environment.generate/
supabase/
  sql/
  functions/
docs/
  ARCHITECTURE.md
  runbooks/
  policies/

## 12) Operating Principles (rules to prevent chaos)
- “No secrets in repo” — ever.
- “No scope expansion without approval” — enforced by manifest baseline + CI.
- “Everything auditable” — events are append-only and reconstructable.
- “Default deny” — network, device access, and permissions.
- “Small v1” — prove reliability first, then add intelligence and media.
