# Keshav Velo License Architecture

## Flow

1. The panel loads `DeviceFingerprint`, `LocalSecureStorage`, `APIClient`, `LicenseManager`, and `ActivationUI`.
2. `LicenseManager.init()` reads the encrypted local session and calls `POST /licenses/verify`.
3. If no valid local session exists, the activation overlay blocks premium tools.
4. On activation, the user submits registered email and license key over HTTPS.
5. The backend checks the license, email, subscription, expiry, and device binding.
6. If the license has no device yet, the backend permanently stores the first device ID.
7. If the stored device ID differs, return `DEVICE_ALREADY_BOUND` and the panel shows: `This license is already activated on another device.`
8. The server returns a short-lived session token, request-signing secret, and offline token.

## Client Modules

- `js/license/DeviceFingerprint.js`: builds a stable hashed device ID from OS identifiers, then sends only hashes to the server.
- `js/license/LocalSecureStorage.js`: stores encrypted session data with AES-256-GCM where CEP Node crypto is available. It never stores the plain license key.
- `js/license/APIClient.js`: forces HTTPS, sends bearer tokens, timestamps, nonces, and HMAC request signatures.
- `js/license/LicenseManager.js`: owns activation, verification, background checks, offline grace, and lock state.
- `js/license/ActivationUI.js`: renders the activation screen and blocks the panel while unlicensed.

## Database Requirements

Use hashed license keys in operational tables. Keep raw license keys only at issuance time, or avoid storing them entirely by storing `license_key_hash`.

Required tables:

- `users`: `id`, `email`, `created_at`
- `licenses`: `id`, `user_id`, `license_key_hash`, `status`, `subscription_status`, `expires_at`, `max_devices`, `created_at`
- `license_activations`: `id`, `license_id`, `device_id`, `fingerprint_version`, `signals_hash`, `extension_version`, `activated_at`, `last_verified_at`, `revoked_at`
- `license_sessions`: `id`, `license_id`, `activation_id`, `session_token_hash`, `request_secret_hash`, `expires_at`, `created_at`, `revoked_at`
- `request_nonces`: `app_id`, `nonce`, `timestamp`, `created_at`
- `license_audit_log`: `id`, `license_id`, `event`, `device_id`, `ip`, `user_agent`, `created_at`, `metadata_json`

## API Contract

`POST /v1/licenses/activate`

Request:

```json
{
  "email": "buyer@example.com",
  "licenseKey": "KVW-XXXX-XXXX",
  "licenseKeyHash": "sha256",
  "deviceId": "sha256",
  "fingerprintVersion": "kwv-device-v1",
  "signalsHash": "sha256",
  "extensionVersion": "1.0.0",
  "host": "after-effects",
  "platform": "win32"
}
```

Success:

```json
{
  "active": true,
  "sessionToken": "opaque-short-lived-token",
  "requestSigningSecret": "opaque-secret",
  "offlineToken": "signed-jws",
  "activationDate": "2026-07-17T10:00:00.000Z",
  "lastVerificationAt": "2026-07-17T10:00:00.000Z",
  "offlineUntil": "2026-07-20T10:00:00.000Z",
  "licenseStatus": "active",
  "subscriptionStatus": "active",
  "expiresAt": null
}
```

Device conflict:

```json
{
  "code": "DEVICE_ALREADY_BOUND",
  "message": "This license is already activated on another device."
}
```

`POST /v1/licenses/verify`

Request is signed with `Authorization: Bearer <sessionToken>` and `X-KWV-Signature`.

```json
{
  "email": "buyer@example.com",
  "licenseKeyHash": "sha256",
  "deviceId": "sha256",
  "fingerprintVersion": "kwv-device-v1",
  "extensionVersion": "1.0.0",
  "lastVerificationAt": "2026-07-17T10:00:00.000Z"
}
```

The server must reject revoked, expired, unpaid, mismatched-device, replayed nonce, stale timestamp, and bad-signature requests.

## Security Notes

- Do not trust client-side JavaScript for final authorization.
- Never put a private API secret in the extension bundle.
- Store only hashes of license keys locally and in lookup tables.
- Use HTTPS only.
- Use server-side rate limits for activation attempts.
- Return short-lived session tokens and rotate request-signing secrets.
- Sign offline tokens on the server with a private key. Put only the public key in the extension.
- Obfuscation can slow casual reverse engineering, but it is not a security boundary.
- For CEP, avoid `--disable-web-security` and `--allow-running-insecure-content` in production if your panel does not absolutely require them.

## UXP Notes

UXP does not expose unrestricted Node APIs like CEP. For UXP, keep the same `LicenseManager` and `APIClient` shape, but replace:

- Device fingerprint collection with UXP-safe host/device values plus a server-issued install ID.
- Local encryption with UXP secure storage if available, or OS credential storage through a native helper.
- `fetch` remains the network layer.

The backend contract should stay identical across CEP and UXP.
