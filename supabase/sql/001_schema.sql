-- v1 schema definition for devices, tasks, approvals, events, artifacts

CREATE TABLE devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID,
    name TEXT,
    role TEXT,
    status TEXT,
    tags JSONB,
    public_key TEXT,
    agent_version TEXT,
    last_seen_at TIMESTAMPTZ,
    halt BOOLEAN,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID,
    capability_name TEXT,
    capability_version TEXT,
    status TEXT,
    risk TEXT,
    input JSONB,
    approvals_required JSONB,
    approvals_satisfied BOOLEAN,
    target_device_id UUID,
    lease_owner_device_id UUID,
    lease_expires_at TIMESTAMPTZ,
    attempt_count INT,
    idempotency_key TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE approvals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID,
    task_id UUID,
    status TEXT,
    approval_type TEXT,
    summary TEXT,
    scope JSONB,
    approved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID,
    event_type TEXT,
    actor_type TEXT,
    actor_id UUID,
    device_id UUID,
    task_id UUID,
    approval_id UUID,
    artifact_id UUID,
    payload JSONB,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE artifacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID,
    task_id UUID,
    device_id UUID,
    artifact_type TEXT,
    retention TEXT,
    bucket TEXT,
    path TEXT,
    content_type TEXT,
    size_bytes BIGINT,
    sha256 TEXT,
    confirmed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Create necessary indexes
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_lease_expires_at ON tasks(lease_expires_at);
CREATE INDEX idx_events_created_at ON events(created_at);
CREATE INDEX idx_artifacts_task_id ON artifacts(task_id);