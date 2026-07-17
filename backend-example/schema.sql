CREATE TABLE users (
    id UUID PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE licenses (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id),
    license_key_hash TEXT NOT NULL UNIQUE,
    status TEXT NOT NULL CHECK (status IN ('active', 'revoked', 'disabled')),
    subscription_status TEXT NOT NULL CHECK (subscription_status IN ('active', 'past_due', 'canceled', 'lifetime')),
    expires_at TIMESTAMPTZ,
    max_devices INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE license_activations (
    id UUID PRIMARY KEY,
    license_id UUID NOT NULL REFERENCES licenses(id),
    device_id TEXT NOT NULL,
    fingerprint_version TEXT NOT NULL,
    signals_hash TEXT,
    extension_version TEXT,
    activated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_verified_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ,
    UNIQUE (license_id, device_id)
);

CREATE TABLE license_sessions (
    id UUID PRIMARY KEY,
    license_id UUID NOT NULL REFERENCES licenses(id),
    activation_id UUID NOT NULL REFERENCES license_activations(id),
    session_token_hash TEXT NOT NULL UNIQUE,
    request_secret_hash TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    revoked_at TIMESTAMPTZ
);

CREATE TABLE request_nonces (
    app_id TEXT NOT NULL,
    nonce TEXT NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (app_id, nonce)
);

CREATE TABLE license_audit_log (
    id UUID PRIMARY KEY,
    license_id UUID REFERENCES licenses(id),
    event TEXT NOT NULL,
    device_id TEXT,
    ip TEXT,
    user_agent TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    metadata_json JSONB NOT NULL DEFAULT '{}'
);
