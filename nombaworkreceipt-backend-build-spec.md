# NombaWorkReceipt — Backend Build Specification

> This document is the single source of truth for building the NombaWorkReceipt backend.  
> Read this fully before writing any code. Follow the build order at the end exactly.

---

## 1. What We're Building

NombaWorkReceipt is a proof-of-work escrow payment system for Nigeria's informal service economy. A merchant (technician, repairer, tailor, etc.) creates a job with a price. A buyer pays into a dedicated Nomba virtual account tied to that job. The merchant performs the work and submits photographic or artifact proof. The buyer reviews and confirms, or a timer auto-releases the funds after a review window. If something's wrong, the buyer can dispute, and an admin resolves it by reviewing an evidence packet.

Every merchant builds a WorkScore — a reputation number derived from completed jobs, dispute history, and earnings — which becomes a portable credibility signal for the informal economy.

This is being built for the Nomba x DevCareer Hackathon 2026 (July 1–7), under team Reed Breed.

---

## 2. Tech Stack — Confirmed

| Layer | Technology |
|---|---|
| Language | Go |
| Web framework | Fiber |
| Database | MySQL |
| Database host | Hostinger (remote MySQL access enabled) — fallback: Railway or Aiven if connection issues arise |
| Backend hosting | Render |
| File storage | Google Cloud Storage (for proof artifacts) |
| Push notifications | Firebase Cloud Messaging |
| Email (OTP delivery) | Brevo |
| Payments / banking | Nomba API (sandbox during development) |
| Mobile frontend | Flutter (built by a separate team member, consumes this API) |
| Background jobs | Go goroutines + MySQL-persisted job state (no Redis) |

> Do NOT introduce Redis, PostgreSQL, Supabase, or any tool not listed above without explicit confirmation.

---

## 3. Project Folder Structure

```
nombaworkreceipt-backend/
├── cmd/
│   └── api/
│       └── main.go                  — entrypoint, starts Fiber server
├── internal/
│   ├── config/
│   │   └── config.go                 — loads env vars
│   ├── database/
│   │   └── mysql.go                  — DB connection setup
│   ├── middleware/
│   │   ├── auth.go                   — JWT verification, role checks
│   │   ├── logger.go                 — structured request logging
│   │   └── cors.go                   — CORS config for Flutter app
│   ├── models/
│   │   ├── user.go
│   │   ├── job.go
│   │   ├── escrow.go
│   │   ├── proof_artifact.go
│   │   ├── dispute.go
│   │   ├── workscore_event.go
│   │   ├── notification.go
│   │   └── webhook_event.go
│   ├── handlers/
│   │   ├── auth_handler.go
│   │   ├── job_handler.go
│   │   ├── escrow_handler.go
│   │   ├── proof_handler.go
│   │   ├── dispute_handler.go
│   │   ├── workscore_handler.go
│   │   ├── notification_handler.go
│   │   ├── admin_handler.go
│   │   ├── webhook_handler.go
│   │   └── health_handler.go
│   ├── services/
│   │   ├── auth_service.go           — OTP generation, JWT issuance
│   │   ├── job_service.go            — job state machine logic
│   │   ├── escrow_service.go         — virtual account, over/under-payment logic
│   │   ├── proof_service.go          — file upload, hash computation
│   │   ├── dispute_service.go        — evidence packet assembly
│   │   ├── workscore_service.go      — score calculation
│   │   ├── notification_service.go   — dispatch to FCM/SMS
│   │   └── reconciliation_service.go — nightly cron logic
│   ├── nomba/
│   │   ├── client.go                 — base HTTP client, token management
│   │   ├── auth.go                   — token issue/refresh
│   │   ├── virtual_account.go        — create/fetch virtual accounts
│   │   ├── transfer.go               — bank lookup + transfer
│   │   ├── webhook.go                — HMAC verification
│   │   └── transactions.go           — list transactions for reconciliation
│   ├── email/
│   │   └── brevo.go                  — Brevo transactional email client (OTP delivery)
│   ├── jobs/                         — background goroutines
│   │   ├── review_timer.go           — auto-release after review window
│   │   ├── reconciliation_cron.go    — nightly reconciliation
│   │   └── webhook_retry.go          — retry failed outbound notifications
│   └── routes/
│       └── routes.go                 — registers all routes
├── migrations/
│   ├── 001_create_users.sql
│   ├── 002_create_jobs.sql
│   ├── 003_create_escrow.sql
│   ├── 004_create_proof_artifacts.sql
│   ├── 005_create_disputes.sql
│   ├── 006_create_workscore_events.sql
│   ├── 007_create_notifications.sql
│   └── 008_create_webhook_events.sql
├── .env.example
├── .gitignore
├── go.mod
├── go.sum
└── README.md
```

---

## 4. Database Schema — Full MySQL Migrations

### 001_create_users.sql
```sql
CREATE TABLE users (
  id VARCHAR(36) PRIMARY KEY,
  phone VARCHAR(20) UNIQUE,
  email VARCHAR(255) UNIQUE,
  password_hash VARCHAR(255),
  name VARCHAR(255),
  role ENUM('merchant', 'buyer', 'admin') NOT NULL,
  nomba_account_id VARCHAR(100),
  bank_code VARCHAR(10),
  bank_account_number VARCHAR(20),
  bank_account_name VARCHAR(255),
  workscore INT DEFAULT 0,
  dispute_score DECIMAL(5,2) DEFAULT 100.00,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE otp_codes (
  id VARCHAR(36) PRIMARY KEY,
  email VARCHAR(255) NOT NULL,
  code VARCHAR(6) NOT NULL,
  expires_at TIMESTAMP NOT NULL,
  used BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE refresh_tokens (
  id VARCHAR(36) PRIMARY KEY,
  user_id VARCHAR(36) NOT NULL,
  token_hash VARCHAR(255) NOT NULL,
  revoked BOOLEAN DEFAULT false,
  expires_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id)
);
```

### 002_create_jobs.sql
```sql
CREATE TABLE jobs (
  id VARCHAR(36) PRIMARY KEY,
  merchant_id VARCHAR(36) NOT NULL,
  buyer_id VARCHAR(36),
  title VARCHAR(255) NOT NULL,
  description TEXT,
  amount_kobo BIGINT NOT NULL,
  advance_drawn_kobo BIGINT DEFAULT 0,
  proof_type ENUM('photo', 'artifact', 'dual_checkin', 'spec_locked', 'functional_signoff') NOT NULL,
  review_window_hours INT NOT NULL DEFAULT 72,
  status ENUM(
    'created',
    'funded',
    'in_progress',
    'proof_submitted',
    'approved',
    'disputed',
    'paid_out',
    'closed',
    'cancelled'
  ) DEFAULT 'created',
  spec_hash VARCHAR(64),
  share_link VARCHAR(500),
  proof_submitted_at TIMESTAMP NULL,
  review_deadline_at TIMESTAMP NULL,
  resolved_at TIMESTAMP NULL,
  resolution ENUM('merchant_wins', 'buyer_wins') NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (merchant_id) REFERENCES users(id),
  FOREIGN KEY (buyer_id) REFERENCES users(id),
  INDEX idx_status (status),
  INDEX idx_merchant (merchant_id),
  INDEX idx_buyer (buyer_id),
  INDEX idx_review_deadline (review_deadline_at)
);
```

### 003_create_escrow.sql
```sql
CREATE TABLE escrow_accounts (
  id VARCHAR(36) PRIMARY KEY,
  job_id VARCHAR(36) NOT NULL UNIQUE,
  virtual_account_number VARCHAR(20) NOT NULL,
  bank_name VARCHAR(100) NOT NULL,
  account_name VARCHAR(255) NOT NULL,
  nomba_account_ref VARCHAR(100) NOT NULL,
  expected_amount_kobo BIGINT NOT NULL,
  received_amount_kobo BIGINT DEFAULT 0,
  status ENUM('awaiting_payment', 'funded', 'over_paid', 'under_paid', 'refunded') DEFAULT 'awaiting_payment',
  funded_at TIMESTAMP NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (job_id) REFERENCES jobs(id)
);

CREATE TABLE payouts (
  id VARCHAR(36) PRIMARY KEY,
  job_id VARCHAR(36) NOT NULL,
  type ENUM('advance', 'final_payout', 'refund') NOT NULL,
  amount_kobo BIGINT NOT NULL,
  fee_kobo BIGINT DEFAULT 0,
  recipient_account_number VARCHAR(20),
  recipient_bank_code VARCHAR(10),
  recipient_account_name VARCHAR(255),
  merchant_tx_ref VARCHAR(100) NOT NULL UNIQUE,
  nomba_transfer_status ENUM('pending', 'successful', 'failed') DEFAULT 'pending',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (job_id) REFERENCES jobs(id)
);
```

### 004_create_proof_artifacts.sql
```sql
CREATE TABLE proof_artifacts (
  id VARCHAR(36) PRIMARY KEY,
  job_id VARCHAR(36) NOT NULL,
  artifact_type ENUM('before_photo', 'after_photo', 'file', 'checkin', 'checkout', 'signoff') NOT NULL,
  storage_url VARCHAR(500) NOT NULL,
  content_hash VARCHAR(64) NOT NULL,
  metadata_hash VARCHAR(64) NOT NULL,
  gps_lat DECIMAL(10,7),
  gps_lng DECIMAL(10,7),
  device_id VARCHAR(100),
  captured_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (job_id) REFERENCES jobs(id)
);

CREATE TABLE checkins (
  id VARCHAR(36) PRIMARY KEY,
  job_id VARCHAR(36) NOT NULL,
  user_id VARCHAR(36) NOT NULL,
  type ENUM('checkin', 'checkout') NOT NULL,
  gps_lat DECIMAL(10,7),
  gps_lng DECIMAL(10,7),
  device_id VARCHAR(100),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (job_id) REFERENCES jobs(id),
  FOREIGN KEY (user_id) REFERENCES users(id)
);
```

### 005_create_disputes.sql
```sql
CREATE TABLE disputes (
  id VARCHAR(36) PRIMARY KEY,
  job_id VARCHAR(36) NOT NULL UNIQUE,
  buyer_id VARCHAR(36) NOT NULL,
  reason_category ENUM('not_completed', 'wrong_spec', 'quality', 'no_show', 'other') NOT NULL,
  description TEXT NOT NULL,
  buyer_evidence_url VARCHAR(500),
  status ENUM('open', 'under_review', 'resolved') DEFAULT 'open',
  resolution ENUM('merchant_wins', 'buyer_wins') NULL,
  resolution_notes TEXT,
  resolved_by VARCHAR(36) NULL,
  resolved_at TIMESTAMP NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (job_id) REFERENCES jobs(id),
  FOREIGN KEY (buyer_id) REFERENCES users(id),
  FOREIGN KEY (resolved_by) REFERENCES users(id)
);
```

### 006_create_workscore_events.sql
```sql
CREATE TABLE workscore_events (
  id VARCHAR(36) PRIMARY KEY,
  merchant_id VARCHAR(36) NOT NULL,
  job_id VARCHAR(36),
  event_type ENUM(
    'job_completed',
    'dispute_lost',
    'dispute_won',
    'earnings_milestone',
    'recency_bonus',
    'inactivity_penalty'
  ) NOT NULL,
  score_delta INT NOT NULL,
  running_score INT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (merchant_id) REFERENCES users(id),
  FOREIGN KEY (job_id) REFERENCES jobs(id)
);
```

### 007_create_notifications.sql
```sql
CREATE TABLE notifications (
  id VARCHAR(36) PRIMARY KEY,
  user_id VARCHAR(36) NOT NULL,
  job_id VARCHAR(36),
  type ENUM(
    'escrow_funded',
    'proof_submitted',
    'review_expiring',
    'payout_released',
    'dispute_filed',
    'dispute_resolved',
    'advance_paid',
    'under_payment',
    'over_payment_refund'
  ) NOT NULL,
  message TEXT NOT NULL,
  read BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (job_id) REFERENCES jobs(id)
);
```

### 008_create_webhook_events.sql
```sql
CREATE TABLE webhook_events (
  id VARCHAR(36) PRIMARY KEY,
  request_id VARCHAR(200) UNIQUE NOT NULL,
  event_type VARCHAR(100) NOT NULL,
  payload JSON NOT NULL,
  status ENUM('received', 'processed', 'failed') DEFAULT 'received',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

---

## 5. Job State Machine — Exact Transitions

```
CREATED
  ↓ (buyer funds virtual account, webhook confirms amountReceived == amountExpected)
FUNDED
  ↓ (merchant submits proof + calls /jobs/:id/complete)
PROOF_SUBMITTED
  ↓ (review_deadline_at reached, no dispute filed)              ↓ (buyer files dispute)
APPROVED (auto-release)                                          DISPUTED
  ↓ (payout triggered)                                           ↓ (admin resolves)
PAID_OUT                                                         APPROVED or back to merchant
  ↓ (final state)                                                 ↓
CLOSED                                                            PAID_OUT → CLOSED
```

Alternative path:
```
PROOF_SUBMITTED
  ↓ (buyer manually confirms via /jobs/:id/confirm)
APPROVED
  ↓ (payout triggered immediately)
PAID_OUT → CLOSED
```

**Rules:**
- A job can only move to `FUNDED` when `amountReceived == amountExpected` exactly. Over/under payment keeps it in `CREATED` with a flag, or moves to `FUNDED` with an excess refund queued.
- `review_deadline_at` is set the moment `proof_submitted_at` is recorded: `proof_submitted_at + review_window_hours`.
- Auto-release only fires if status is still `PROOF_SUBMITTED` when the goroutine wakes — if a dispute was filed in the meantime, skip auto-release.
- Every payout (`PAID_OUT` transition) must call `/transfers/bank/lookup` before `/transfers/bank`.

---

## 6. Nomba Integration — Implementation Rules

### Authentication
- Authenticate using parent `accountId` in the `accountId` header (from the hackathon credentials email)
- Scope all calls to the sub-account ID
- Store both `accountId` and `sub-account ID` in env vars, never hardcoded
- Tokens expire — implement auto-refresh before expiry, not on failure

### Virtual Accounts
- Create one virtual account per job, immediately on `POST /jobs`
- `accountRef` = job UUID (so Nomba account maps directly to your job)
- Always send amount in **kobo** — multiply naira by 100 before sending, never send raw naira values

### Webhooks
- Endpoint: `POST /webhooks/nomba`
- Use raw body parsing (not JSON middleware) before HMAC verification
- Verify `nomba-signature` header using HMAC-SHA256 with `NOMBA_WEBHOOK_SECRET`
- Reject with `401` if signature doesn't match
- Check `event.requestId` against `webhook_events` table — if it already exists, return `200` immediately without reprocessing
- Store every event in `webhook_events` before processing
- Respond `200` immediately, process the business logic asynchronously if it takes longer than a few hundred milliseconds

### Over/Under-Payment Logic (in webhook handler)
```
if amountReceived == amountExpected:
    mark escrow as funded
    update job status to FUNDED
    start review timer (set on proof submission, not here)
    notify both parties

if amountReceived < amountExpected:
    mark escrow as under_paid
    keep job status as CREATED
    notify buyer: "You sent ₦X short. Please top up ₦Y to fund this job."

if amountReceived > amountExpected:
    mark escrow as funded (job proceeds)
    update job status to FUNDED
    queue a refund payout for the excess amount
    notify buyer: "You overpaid by ₦X. A refund has been queued."
```

### Bank Transfers (Payouts)
- ALWAYS call `POST /transfers/bank/lookup` before `POST /transfers/bank`
- Store the resolved `accountName` and compare it against what's on file — if mismatched, flag for manual review rather than silently proceeding
- Generate a unique `merchantTxRef` for every transfer attempt — never reuse refs, even on retry. Use format: `payout_{job_id}_{timestamp}` or similar
- On `payout.failed` webhook event, retry up to 3 times with exponential backoff, then alert admin via notification

### Reconciliation
- Nightly cron job (`internal/jobs/reconciliation_cron.go`)
- Calls `GET /transactions` for the previous 24 hours
- Compares each transaction's `merchantTxRef` against your `payouts` and `escrow_accounts` tables
- Logs orphan transactions (exist on Nomba, not in your DB) and amount drift (same ref, different amount)
- Store results for `GET /admin/reconciliation/log` to read

---

## 7. Email OTP — Brevo Implementation Rules

Authentication is fully email-based. No SMS, no phone-based OTP.

### Flow
1. `POST /auth/otp/send` — user submits email
2. Backend generates a 6-digit numeric OTP
3. OTP is hashed (e.g. bcrypt or SHA-256) and stored in `otp_codes` with a 5-minute expiry — never store the raw OTP in the database
4. Backend calls Brevo's transactional email API to send the OTP to the user's email
5. `POST /auth/otp/verify` — user submits email + OTP
6. Backend hashes the submitted OTP and compares against the stored hash, checks expiry and `used` flag
7. On match: mark `otp_codes` row as `used`, issue JWT + refresh token, create the user record if this is their first time (`is_new_user: true` in response)

### Brevo API Call
```go
// internal/email/brevo.go
func SendOTPEmail(toEmail string, otpCode string) error {
  payload := map[string]interface{}{
    "sender": map[string]string{
      "name":  "NombaWorkReceipt",
      "email": os.Getenv("BREVO_SENDER_EMAIL"),
    },
    "to": []map[string]string{
      {"email": toEmail},
    },
    "subject": "Your NombaWorkReceipt verification code",
    "htmlContent": fmt.Sprintf("<p>Your verification code is <strong>%s</strong>. It expires in 5 minutes.</p>", otpCode),
  }

  body, _ := json.Marshal(payload)
  req, _ := http.NewRequest("POST", "https://api.brevo.com/v3/smtp/email", bytes.NewBuffer(body))
  req.Header.Set("api-key", os.Getenv("BREVO_API_KEY"))
  req.Header.Set("Content-Type", "application/json")

  resp, err := http.DefaultClient.Do(req)
  if err != nil {
    return err
  }
  defer resp.Body.Close()

  if resp.StatusCode >= 300 {
    return fmt.Errorf("brevo send failed: status %d", resp.StatusCode)
  }
  return nil
}
```

### Rules
- Never log the raw OTP code in plaintext anywhere — not in console logs, not in error messages
- OTP expires in 5 minutes — enforce this at the database query level (`WHERE expires_at > NOW() AND used = false`), not just in application logic
- Rate limit `POST /auth/otp/send` to 3 requests per email per 10 minutes (already defined in the Middleware section)
- If Brevo's API call fails, return a clear `500` error to the user (`EMAIL_SEND_FAILED`) — do not silently succeed and leave the user waiting for an email that never arrives
- For local development/testing, consider logging the OTP to your server console (never to a file or persistent log) behind an `ENV=development` check, so you can test the flow without waiting on real emails

---

## 8. Transaction Safety — Database & Nomba Call Rules

This section exists because multi-step operations are the easiest place for a hackathon backend to silently corrupt data. Follow these rules exactly.

### When to Wrap Operations in a MySQL Transaction

Any time a single logical action touches more than one table, wrap it in a MySQL transaction (`BEGIN` / `COMMIT` / `ROLLBACK`, or `db.Begin()` in Go). If any step fails, roll back everything — never leave the database in a half-updated state.

**Dispute resolution** (`PATCH /disputes/:id/resolve`) touches four things — this MUST be one transaction:
```go
tx, err := db.Begin()
if err != nil { return err }
defer tx.Rollback() // no-op if committed

// 1. Update disputes table (status, resolution, resolved_by, resolved_at)
// 2. Update jobs table (status -> approved/paid_out, resolved_at)
// 3. Insert workscore_events row + update users.workscore
// 4. Insert payouts row (status: pending, before calling Nomba)

if err := tx.Commit(); err != nil { return err }

// ONLY AFTER COMMIT: call Nomba /transfers/bank/lookup then /transfers/bank
// If the Nomba call fails after commit, the payout row stays "pending" —
// the reconciliation cron and webhook retry logic will catch and resolve it later.
// Do NOT call Nomba inside the transaction — external API calls inside a DB
// transaction hold locks open and can time out the transaction itself.
```

**Job funding via webhook** (`POST /webhooks/nomba`, `transfer.successful` event) touches three things — also one transaction:
```
1. Update escrow_accounts (received_amount_kobo, status, funded_at)
2. Update jobs (status -> funded)
3. Insert notification rows for both merchant and buyer
```

**Job completion + auto-release / confirm** touches: jobs table, payouts table (insert as `pending` before the Nomba call), workscore_events. Same pattern — commit the DB transaction first, call Nomba after, let reconciliation catch any drift.

### The Core Rule: DB Commit Before External Call

Never call the Nomba API from inside an open MySQL transaction. Always:
1. Open transaction
2. Make all DB writes, including inserting a `payouts` row with `nomba_transfer_status = 'pending'`
3. Commit the transaction
4. Only then call Nomba (`/transfers/bank/lookup` → `/transfers/bank`)
5. Update the `payouts` row's `nomba_transfer_status` to `successful` or `failed` based on the result — this is a separate, single-row update, not part of the original transaction

This way, even if Nomba's API is slow or times out, your database isn't holding locks waiting on an external HTTP call, and you always have a `pending` payout row that reconciliation can pick up and resolve later instead of losing track of it entirely.

### Nomba Call Retry Pattern — Check Before Retry

If a call to `/transfers/bank` times out or returns an ambiguous error (not a clean success or clean failure), do NOT immediately retry with a new call. A timeout doesn't mean the transfer didn't happen — it might have succeeded on Nomba's side while the response was lost.

Correct pattern:
```go
func SafeTransfer(merchantTxRef string, ...) error {
  // 1. Attempt the transfer
  err := nomba.Transfer(merchantTxRef, ...)
  if err == nil {
    return nil // clean success
  }

  // 2. On any error/timeout, check status before retrying
  status, checkErr := nomba.GetTransferStatus(merchantTxRef)
  if checkErr == nil && status == "successful" {
    return nil // it actually succeeded, just the original response was lost
  }
  if checkErr == nil && status == "failed" {
    // safe to retry — generate a NEW merchantTxRef for the retry attempt
    return RetryWithNewRef(...)
  }

  // 3. Still unclear — do not retry blindly. Mark as pending_review and alert admin.
  return MarkPendingReview(merchantTxRef)
}
```

Never call `/transfers/bank` twice with the same `merchantTxRef` expecting Nomba's idempotency to save you — confirm status first. Reserve a brand new `merchantTxRef` only for genuine retries after confirming the original attempt actually failed.

### MySQL Connection Pool Settings

Set explicit pool limits on startup (`internal/database/mysql.go`) — Go's default `sql.DB` has no limit on open connections, which can exhaust your Hostinger MySQL connection cap under any concurrent load, even hackathon-level demo traffic from judges.

```go
db.SetMaxOpenConns(20)
db.SetMaxIdleConns(10)
db.SetConnMaxLifetime(5 * time.Minute)
```

---

## 9. Middleware — Full Specification

This is the complete middleware stack. Apply in this order on every request (order matters — recovery and logging wrap everything, CORS and body limits run early, auth runs last before the handler).

### Global Middleware (applied to all routes)

**1. Recover Middleware**
Use Fiber's built-in `recover` middleware first in the chain. If any handler panics (nil pointer, index out of range, etc.), this catches it and returns a `500` instead of crashing the entire server.
```go
app.Use(recover.New())
```

**2. Request ID Middleware**
Attach a unique request ID to every incoming request. Include it in every log line for that request. Critical for tracing a single webhook delivery or API call through your logs when debugging.
```go
app.Use(requestid.New())
```

**3. Structured Logger Middleware**
Custom middleware (`internal/middleware/logger.go`). For every request, log: timestamp, request ID, method, path, status code, latency, and — critically — `merchantTxRef` whenever the request involves a Nomba call. This is a cert/judging requirement, not optional.
```
[2026-06-30T10:00:00Z] req_id=abc123 POST /jobs/:id/advance status=200 latency=340ms merchantTxRef=adv_xyz
```

**4. CORS Middleware**
```go
app.Use(cors.New(cors.Config{
  AllowOrigins: "*", // tighten to your Flutter app's domain / admin dashboard domain before production
  AllowMethods: "GET,POST,PATCH,DELETE,OPTIONS",
  AllowHeaders: "Origin, Content-Type, Accept, Authorization",
}))
```
> Note: Flutter mobile apps are not browsers and are not subject to CORS — this matters mainly for your future web admin dashboard (W14) and any browser-based testing tools (Postman is also exempt). Keep `AllowOrigins: "*"` during the hackathon for simplicity, tighten before any real production use.

**5. Body Limit Middleware**
Set Fiber's server-level body limit to handle proof artifact uploads (photos can be a few MB).
```go
app = fiber.New(fiber.Config{
  BodyLimit: 10 * 1024 * 1024, // 10MB, matches FILE_TOO_LARGE rule in API spec
})
```

**6. Rate Limiter Middleware**
Apply globally as a baseline anti-abuse measure, with a stricter limit specifically on OTP routes.
```go
// Global baseline
app.Use(limiter.New(limiter.Config{
  Max:        100,
  Expiration: 1 * time.Minute,
}))

// Stricter limit on OTP specifically (apply only to /auth/otp/send route group)
otpLimiter := limiter.New(limiter.Config{
  Max:        3,
  Expiration: 10 * time.Minute,
  KeyGenerator: func(c *fiber.Ctx) string {
    return c.FormValue("email") // rate limit per email address, not per IP
  },
})
```

### Route-Specific Middleware

**7. Auth Middleware (`internal/middleware/auth.go`)**
Two functions:
- `RequireAuth()` — verifies JWT is present and valid, attaches `user_id` and `role` to context. Used on all `authenticated` routes.
- `RequireRole(roles ...string)` — runs after `RequireAuth()`, checks the attached role against allowed roles for that route. Used on `merchant`, `buyer`, and `admin` routes.

```go
// Example usage in routes.go
jobs := app.Group("/jobs", middleware.RequireAuth())
jobs.Post("/", middleware.RequireRole("merchant"), jobHandler.CreateJob)
jobs.Get("/:id", jobHandler.GetJob) // any authenticated role
jobs.Post("/:id/dispute", middleware.RequireRole("buyer"), disputeHandler.FileDispute)

admin := app.Group("/admin", middleware.RequireAuth(), middleware.RequireRole("admin"))
admin.Get("/stats", adminHandler.GetStats)
```

**8. Request Validation**
Use `go-playground/validator` with struct tags on every request body. Reject malformed requests before they reach service logic.
```go
type CreateJobRequest struct {
  Title              string `json:"title" validate:"required,min=3,max=255"`
  AmountKobo         int64  `json:"amount_kobo" validate:"required,min=1"`
  ProofType          string `json:"proof_type" validate:"required,oneof=photo artifact dual_checkin spec_locked functional_signoff"`
  ReviewWindowHours  int    `json:"review_window_hours" validate:"required,oneof=24 72 168"`
}
```
Return a `400` with a clear error message (matching the standard error response shape in the API spec) on validation failure — never let invalid data reach the database layer.

**9. Webhook Route Exception**
The `/webhooks/nomba` route must NOT use the standard JSON body parser or the standard auth middleware. It needs:
- Raw body parsing (`fiber.Ctx.Body()` directly, not auto-parsed JSON) so the HMAC signature can be verified against the exact raw bytes
- Its own HMAC verification function instead of JWT auth
- Should be registered outside the `authenticated` route group entirely

### Graceful Shutdown

Render redeploys can terminate your process mid-request. Implement graceful shutdown so in-flight requests finish and the DB connection closes cleanly:

```go
c := make(chan os.Signal, 1)
signal.Notify(c, os.Interrupt, syscall.SIGTERM)
go func() {
  <-c
  app.ShutdownWithTimeout(10 * time.Second)
}()
```

---

## 10. Security Requirements — Non-Negotiable

- `NOMBA_CLIENT_ID`, `NOMBA_PRIVATE_KEY` (or `client_secret` — confirm exact field name Nomba expects), `NOMBA_WEBHOOK_SECRET`, JWT secret, and all DB credentials live in environment variables only — never in source code, never committed to git
- `.env` must be in `.gitignore` from the very first commit
- Every webhook handler verifies HMAC signature before processing anything
- Every external write (payouts, advances, refunds) is keyed on a unique `merchantTxRef` to guarantee idempotency
- JWT auth middleware checks both token validity and role — a buyer token must never be able to hit a merchant-only or admin-only route
- Admin routes require role `admin` explicitly — there is no implicit admin access
- Passwords (admin login) are hashed with bcrypt, never stored plaintext
- Rate limit OTP requests per email address to prevent abuse
- All file uploads (proof artifacts) are validated for file type and size (max 10MB) before upload to GCS
- SQL queries use parameterized statements exclusively — no string concatenation into SQL ever

---

## 11. Background Jobs — Go Goroutines

### Review Timer (`internal/jobs/review_timer.go`)
- On `proof_submitted_at`, calculate `review_deadline_at = proof_submitted_at + review_window_hours`
- A goroutine (or scheduled poller checking the DB every minute for jobs past their `review_deadline_at` with status still `PROOF_SUBMITTED`) triggers auto-release
- On trigger: call `/transfers/bank/lookup`, then `/transfers/bank`, update job to `APPROVED` then `PAID_OUT`
- Must be idempotent — if the goroutine fires twice somehow, the unique `merchantTxRef` constraint in `payouts` table prevents double payout

### Reconciliation Cron (`internal/jobs/reconciliation_cron.go`)
- Runs once every 24 hours (use a simple ticker or cron library like `robfig/cron`)
- Pulls `GET /transactions` and compares against internal records
- Logs results to a queryable format for the admin endpoint

### Webhook Retry (`internal/jobs/webhook_retry.go`)
- If any internal notification dispatch (FCM, SMS) fails, retry with exponential backoff (e.g. 1min, 5min, 15min) up to 3 attempts before giving up and logging the failure

---

## 12. Environment Variables (.env.example)

```env
# Server
PORT=8080
ENV=development

# Database
DB_HOST=
DB_PORT=3306
DB_USER=
DB_PASSWORD=
DB_NAME=

# JWT
JWT_SECRET=
JWT_EXPIRY_HOURS=24
REFRESH_TOKEN_EXPIRY_DAYS=30

# Nomba
NOMBA_BASE_URL=https://sandbox.api.nomba.com/v1
NOMBA_ACCOUNT_ID=
NOMBA_SUB_ACCOUNT_ID=
NOMBA_CLIENT_ID=
NOMBA_PRIVATE_KEY=
NOMBA_WEBHOOK_SECRET=

# Google Cloud Storage
GCS_BUCKET_NAME=
GCS_CREDENTIALS_JSON=

# Firebase
FCM_SERVER_KEY=

# Brevo (Email OTP)
BREVO_API_KEY=
BREVO_SENDER_EMAIL=

# Admin
ADMIN_DEFAULT_EMAIL=
ADMIN_DEFAULT_PASSWORD=
```

---

## 13. API Routes Reference

> Full request/response shapes for every route are documented in the companion file `nombaworkreceipt-api-spec.md`. Build exactly to that spec — do not invent different field names or response shapes.

Quick index of all 35 routes:

```
POST   /auth/otp/send
POST   /auth/otp/verify
POST   /auth/token/refresh
POST   /auth/logout
GET    /auth/me
PATCH  /auth/me
POST   /auth/admin/login

POST   /jobs
GET    /jobs
GET    /jobs/:id
POST   /jobs/:id/accept
GET    /jobs/:id/share-link
POST   /jobs/:id/complete

GET    /jobs/:id/escrow
POST   /jobs/:id/advance

POST   /webhooks/nomba

POST   /jobs/:id/proof
GET    /jobs/:id/proof
POST   /jobs/:id/checkin
POST   /jobs/:id/checkout

POST   /jobs/:id/confirm
POST   /jobs/:id/dispute
GET    /disputes/:id
GET    /disputes
PATCH  /disputes/:id/resolve

GET    /workscore/:merchantId
GET    /workscore/:merchantId/history

GET    /notifications
PATCH  /notifications/:id/read
PATCH  /notifications/read-all

GET    /admin/stats
GET    /admin/merchants
GET    /admin/workscore/distribution
GET    /admin/reconciliation/log

GET    /health
```

---

## 14. WorkScore Formula

```
score = base_score (start at 0)
      + (completed_jobs × 10)
      - (disputes_lost × 25)
      + earnings_tier_bonus      (tiered: +5 per ₦100,000 in lifetime completed payouts, capped at +50)
      + recency_bonus            (+5 if active in last 30 days)
      - inactivity_penalty       (-10 if no activity in 90+ days)

Tiers:
  Bronze:   0–299
  Silver:   300–599
  Gold:     600–849
  Platinum: 850–1000

Score is clamped between 0 and 1000.
```

Every score change is logged as a row in `workscore_events` with the delta and running total — never just overwrite the score directly on the user row without an event log entry.

---

## 15. Build Order — Follow This Sequence

```
Phase 1 — Foundation
  1. go mod init, install Fiber, MySQL driver, JWT library, uuid library, go-playground/validator, fiber middleware packages (cors, limiter, recover, requestid)
  2. Set up folder structure exactly as defined in Section 3
  3. Write all 8 migration files, run them against the Hostinger MySQL DB
  4. Build config loader (internal/config/config.go) reading from .env
  5. Build DB connection (internal/database/mysql.go)
  6. Apply global middleware stack from Section 9 (recover, request ID, logger, CORS, body limit, rate limiter)
  7. Build health check route — GET /health — confirm DB connects
  8. Deploy skeleton to Render, confirm live URL works
  9. Register webhook URL with Nomba (https://your-render-url/webhooks/nomba)

Phase 2 — Auth Module
  10. Build Brevo email client (internal/email/brevo.go), test it sends a real email
  11. Build OTP generation/hashing/storage logic, send/verify endpoints, JWT issuance, refresh token logic
  12. Build auth middleware (role-based route protection)
  13. Build GET /auth/me, PATCH /auth/me
  14. Build admin login (separate from OTP flow)

Phase 3 — Nomba Integration Layer
  15. Build internal/nomba/client.go — base HTTP client with token management
  16. Build token issue/refresh against Nomba sandbox
  17. Build virtual account creation function
  18. Build webhook HMAC verification function
  19. Build bank lookup + transfer functions
  20. Build transactions list function (for reconciliation later)

Phase 4 — Jobs + Escrow
  21. Build POST /jobs — creates job + Nomba virtual account in same call
  22. Build GET /jobs, GET /jobs/:id, POST /jobs/:id/accept
  23. Build POST /webhooks/nomba — full event handling with idempotency and over/under-payment logic
  24. Build GET /jobs/:id/escrow
  25. Build POST /jobs/:id/advance

Phase 5 — Proof + Timer
  26. Build GCS upload integration
  27. Build POST /jobs/:id/proof, GET /jobs/:id/proof
  28. Build POST /jobs/:id/checkin, POST /jobs/:id/checkout
  29. Build POST /jobs/:id/complete
  30. Build review timer goroutine/poller for auto-release

Phase 6 — Confirm + Dispute
  31. Build POST /jobs/:id/confirm (manual buyer approval + payout, follow Transaction Safety rules from Section 8)
  32. Build POST /jobs/:id/dispute
  33. Build GET /disputes, GET /disputes/:id (evidence packet assembly)
  34. Build PATCH /disputes/:id/resolve (MUST wrap in MySQL transaction per Section 8 — disputes, jobs, workscore_events, payouts all update together)

Phase 7 — WorkScore + Notifications
  35. Build WorkScore calculation service, trigger on job completion and dispute resolution
  36. Build GET /workscore/:merchantId, GET /workscore/:merchantId/history
  37. Build notification dispatch service (FCM + Brevo)
  38. Build GET /notifications, PATCH /notifications/:id/read, PATCH /notifications/read-all

Phase 8 — Admin + Reconciliation
  39. Build GET /admin/stats, GET /admin/merchants, GET /admin/workscore/distribution
  40. Build reconciliation cron job
  41. Build GET /admin/reconciliation/log

Phase 9 — Hardening
  42. Add structured logging with merchantTxRef tagged on every Nomba call
  43. Add rate limiting on OTP endpoints
  44. Test every error code path defined in the API spec
  45. Test webhook duplicate delivery handling
  46. Test over-payment and under-payment scenarios end-to-end
  47. Final QA against the full API spec
```

---

## 16. Things to NOT Build (Stubbed for This Hackathon)

- Marketplace SDK — out of scope, do not build
- WhatsApp Meta Business API integration — out of scope
- Tokenized card recurring charges — out of scope
- WorkScore-based credit/lending API — out of scope
- iOS-specific code — Android only for this build

USSD is planned as a follow-up addition after the core mobile flow is stable — do not start it until Phases 1–6 above are complete and tested.

---

## 17. Critical Reminders for the Coding Agent

- Every amount sent to Nomba must be in kobo. Never send raw naira values.
- Every payout must call `/transfers/bank/lookup` first, no exceptions.
- Every webhook must verify HMAC before touching the payload.
- Every external write must use a unique `merchantTxRef`.
- Never hardcode secrets — always read from environment variables.
- Use parameterized SQL queries everywhere, never string concatenation.
- Match the API spec's exact field names and response shapes — the Flutter frontend depends on it.
- Do not introduce Redis, PostgreSQL, or any database/tool not listed in Section 2.
- Apply the full middleware stack from Section 9 — recover, request ID, logger, CORS, body limit, rate limiter — before building any route handlers.
- The webhook route is the one exception to standard middleware — raw body parsing, no JWT auth, its own HMAC check.
- Validate every request body with struct tags before it reaches service logic — never trust client input.
- Implement graceful shutdown so Render redeploys don't drop in-flight requests or leave the DB connection dangling.
- Any operation touching more than one table (dispute resolution, webhook funding, payout triggers) must be wrapped in a MySQL transaction — see Section 8.
- Never call the Nomba API from inside an open database transaction — commit first, call Nomba after, update the payout row status in a separate write.
- Before retrying a failed or timed-out Nomba transfer call, check its status via `GET /transfers/{merchantTxRef}` first — never blindly retry with the same reference.

---

*NombaWorkReceipt Backend Build Specification — Reed Breed Technologies — June 2026*
