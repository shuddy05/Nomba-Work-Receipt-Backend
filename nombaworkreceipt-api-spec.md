# NombaWorkReceipt — Backend API Specification

> Version: 1.0  
> Stack: Go + Fiber, MySQL (PlanetScale), hosted on Render  
> Base URL (dev): `http://localhost:8080`  
> Base URL (prod): `https://nombaworkreceipt.onrender.com`  
> All request and response bodies are JSON unless stated otherwise  
> All amounts are in **kobo** (₦1 = 100 kobo)  
> All timestamps are ISO 8601 UTC strings

---

## Auth Levels

| Level | Meaning |
|---|---|
| `public` | No token required |
| `authenticated` | Valid JWT required — any role |
| `merchant` | Valid JWT + role must be `merchant` |
| `buyer` | Valid JWT + role must be `buyer` |
| `admin` | Valid JWT + role must be `admin` |

---

## Standard Error Response

All errors follow this shape:

```json
{
  "success": false,
  "error": {
    "code": "INVALID_OTP",
    "message": "The OTP you entered is incorrect or has expired."
  }
}
```

---

## Standard Success Response

All success responses follow this shape:

```json
{
  "success": true,
  "data": { }
}
```

---

## 1. Auth Module

### POST /auth/otp/send
Send OTP to an email address.

**Auth:** `public`

**Request Body:**
```json
{
  "email": "ada@example.com"
}
```

**Success Response `200`:**
```json
{
  "success": true,
  "data": {
    "message": "OTP sent successfully.",
    "expires_in": 300
  }
}
```

**Error Codes:**
- `INVALID_EMAIL` — email format is invalid
- `OTP_RATE_LIMIT` — too many OTP requests, try again later

---

### POST /auth/otp/verify
Verify OTP. Returns JWT if valid. Registers user if first time.

**Auth:** `public`

**Request Body:**
```json
{
  "email": "ada@example.com",
  "otp": "482910",
  "role": "merchant"
}
```

> `role` is only required on first-time registration. Accepted values: `merchant`, `buyer`. Ignored if user already exists.

**Success Response `200`:**
```json
{
  "success": true,
  "data": {
    "access_token": "eyJhbGciOiJIUzI1NiIs...",
    "refresh_token": "dGhpcyBpcyBhIHJlZnJlc2g...",
    "user": {
      "id": "uuid",
      "email": "ada@example.com",
      "name": null,
      "role": "merchant",
      "created_at": "2026-06-29T10:00:00Z"
    },
    "is_new_user": true
  }
}
```

**Error Codes:**
- `INVALID_OTP` — OTP is wrong or expired
- `INVALID_ROLE` — role value is not accepted

---

### POST /auth/token/refresh
Refresh an expired access token.

**Auth:** `public`

**Request Body:**
```json
{
  "refresh_token": "dGhpcyBpcyBhIHJlZnJlc2g..."
}
```

**Success Response `200`:**
```json
{
  "success": true,
  "data": {
    "access_token": "eyJhbGciOiJIUzI1NiIs...",
    "refresh_token": "dGhpcyBpcyBhIHJlZnJlc2g..."
  }
}
```

**Error Codes:**
- `INVALID_REFRESH_TOKEN` — token is invalid or expired
- `TOKEN_REVOKED` — token has been revoked

---

### POST /auth/logout
Revoke current session tokens.

**Auth:** `authenticated`

**Request Body:** none

**Success Response `200`:**
```json
{
  "success": true,
  "data": {
    "message": "Logged out successfully."
  }
}
```

---

### GET /auth/me
Get current authenticated user profile.

**Auth:** `authenticated`

**Success Response `200`:**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "email": "ada@example.com",
    "phone": "+2348012345678",
    "name": "Adaeze Okafor",
    "role": "merchant",
    "nomba_account_id": "acc_xxxx",
    "dispute_score": 100.00,
    "created_at": "2026-06-29T10:00:00Z"
  }
}
```

---

### PATCH /auth/me
Update current user profile (name, bank details).

**Auth:** `authenticated`

**Request Body:**
```json
{
  "name": "Adaeze Okafor",
  "bank_code": "044",
  "bank_account_number": "0123456789"
}
```

**Success Response `200`:**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "name": "Adaeze Okafor",
    "bank_account_name": "ADAEZE OKAFOR",
    "bank_code": "044",
    "bank_account_number": "0123456789"
  }
}
```

> Backend calls `/transfers/bank/lookup` internally to verify and return `bank_account_name` before saving.

**Error Codes:**
- `INVALID_BANK_ACCOUNT` — account number could not be resolved via Nomba lookup

---

### POST /auth/admin/login
Admin-only login with email and password (not OTP).

**Auth:** `public`

**Request Body:**
```json
{
  "email": "admin@nombaworkreceipt.com",
  "password": "securepassword"
}
```

**Success Response `200`:**
```json
{
  "success": true,
  "data": {
    "access_token": "eyJhbGciOiJIUzI1NiIs...",
    "user": {
      "id": "uuid",
      "email": "admin@nombaworkreceipt.com",
      "role": "admin"
    }
  }
}
```

**Error Codes:**
- `INVALID_CREDENTIALS` — email or password is wrong
- `NOT_ADMIN` — account exists but is not an admin role

---

## 2. Jobs Module

### POST /jobs
Merchant creates a new job.

**Auth:** `merchant`

**Request Body:**
```json
{
  "title": "Fix my generator",
  "description": "Generator stopped working after the rain. Need a technician.",
  "amount_kobo": 4000000,
  "proof_type": "photo",
  "review_window_hours": 72,
  "advance_requested": false
}
```

> Accepted `proof_type` values: `photo`, `artifact`, `dual_checkin`, `spec_locked`, `functional_signoff`  
> Accepted `review_window_hours` values: `24`, `72`, `168`

**Success Response `201`:**
```json
{
  "success": true,
  "data": {
    "id": "job-uuid",
    "title": "Fix my generator",
    "description": "Generator stopped working after the rain. Need a technician.",
    "amount_kobo": 4000000,
    "proof_type": "photo",
    "review_window_hours": 72,
    "status": "created",
    "merchant_id": "merchant-uuid",
    "buyer_id": null,
    "spec_hash": "sha256hash",
    "share_link": "https://nombaworkreceipt.onrender.com/jobs/job-uuid/pay",
    "escrow": {
      "virtual_account_number": "9901234567",
      "bank_name": "Nomba MFB",
      "account_name": "WorkReceipt — Fix my generator",
      "amount_kobo": 4000000
    },
    "created_at": "2026-06-29T10:00:00Z"
  }
}
```

> Virtual account is created immediately on job creation. `share_link` is the URL merchant sends to buyer via WhatsApp.

**Error Codes:**
- `INVALID_PROOF_TYPE` — proof type not accepted
- `INVALID_AMOUNT` — amount must be greater than 0
- `NOMBA_VA_FAILED` — virtual account creation failed on Nomba side

---

### GET /jobs
List jobs for the authenticated user.

**Auth:** `authenticated`

**Query Parameters:**
```
status=funded          — filter by status (optional)
page=1                 — pagination (default: 1)
limit=20               — results per page (default: 20)
```

**Success Response `200`:**
```json
{
  "success": true,
  "data": {
    "jobs": [
      {
        "id": "job-uuid",
        "title": "Fix my generator",
        "amount_kobo": 4000000,
        "status": "funded",
        "proof_type": "photo",
        "review_deadline_at": "2026-07-02T10:00:00Z",
        "created_at": "2026-06-29T10:00:00Z"
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 20,
      "total": 45
    }
  }
}
```

> Returns merchant's own jobs if role is `merchant`. Returns buyer's jobs if role is `buyer`.

---

### GET /jobs/:id
Get full detail of a single job.

**Auth:** `authenticated`

**Success Response `200`:**
```json
{
  "success": true,
  "data": {
    "id": "job-uuid",
    "title": "Fix my generator",
    "description": "Generator stopped working after the rain.",
    "amount_kobo": 4000000,
    "advance_drawn_kobo": 0,
    "proof_type": "photo",
    "review_window_hours": 72,
    "status": "funded",
    "spec_hash": "sha256hash",
    "share_link": "https://nombaworkreceipt.onrender.com/jobs/job-uuid/pay",
    "merchant": {
      "id": "merchant-uuid",
      "name": "Chidi Repairs",
      "workscore": 720
    },
    "buyer": {
      "id": "buyer-uuid",
      "name": "Emeka Obi"
    },
    "escrow": {
      "virtual_account_number": "9901234567",
      "bank_name": "Nomba MFB",
      "account_name": "WorkReceipt — Fix my generator",
      "amount_kobo": 4000000,
      "funded_at": "2026-06-29T11:30:00Z"
    },
    "review_deadline_at": "2026-07-02T11:30:00Z",
    "proof_submitted_at": null,
    "resolved_at": null,
    "resolution": null,
    "created_at": "2026-06-29T10:00:00Z"
  }
}
```

**Error Codes:**
- `JOB_NOT_FOUND` — job does not exist
- `UNAUTHORIZED` — user is not the merchant or buyer on this job

---

### POST /jobs/:id/accept
Buyer accepts a job link and gets attached to the job.

**Auth:** `buyer`

**Request Body:** none

**Success Response `200`:**
```json
{
  "success": true,
  "data": {
    "id": "job-uuid",
    "title": "Fix my generator",
    "amount_kobo": 4000000,
    "status": "created",
    "buyer_id": "buyer-uuid",
    "escrow": {
      "virtual_account_number": "9901234567",
      "bank_name": "Nomba MFB",
      "account_name": "WorkReceipt — Fix my generator",
      "amount_kobo": 4000000
    }
  }
}
```

**Error Codes:**
- `JOB_NOT_FOUND` — job does not exist
- `JOB_ALREADY_ACCEPTED` — a buyer is already attached to this job
- `JOB_NOT_AVAILABLE` — job status is not `created`

---

### GET /jobs/:id/share-link
Get the shareable payment link for a job.

**Auth:** `merchant`

**Success Response `200`:**
```json
{
  "success": true,
  "data": {
    "share_link": "https://nombaworkreceipt.onrender.com/jobs/job-uuid/pay",
    "whatsapp_link": "https://wa.me/?text=Please%20pay%20for%20my%20service%20here%3A%20https%3A..."
  }
}
```

---

### POST /jobs/:id/complete
Merchant marks job as complete after submitting proof. Triggers `PROOF_SUBMITTED` state.

**Auth:** `merchant`

**Request Body:** none

**Success Response `200`:**
```json
{
  "success": true,
  "data": {
    "id": "job-uuid",
    "status": "proof_submitted",
    "proof_submitted_at": "2026-06-30T09:00:00Z",
    "review_deadline_at": "2026-07-03T09:00:00Z"
  }
}
```

**Error Codes:**
- `JOB_NOT_FUNDED` — job has not been funded yet
- `NO_PROOF_SUBMITTED` — merchant must upload proof before marking complete
- `INVALID_STATE` — job is not in a state that allows this action

---

## 3. Escrow Module

### GET /jobs/:id/escrow
Get escrow details for a job (virtual account number, funding status).

**Auth:** `authenticated`

**Success Response `200`:**
```json
{
  "success": true,
  "data": {
    "job_id": "job-uuid",
    "virtual_account_number": "9901234567",
    "bank_name": "Nomba MFB",
    "account_name": "WorkReceipt — Fix my generator",
    "expected_amount_kobo": 4000000,
    "received_amount_kobo": 0,
    "status": "awaiting_payment",
    "funded_at": null
  }
}
```

---

### POST /jobs/:id/advance
Merchant draws materials advance from funded escrow.

**Auth:** `merchant`

**Request Body:**
```json
{
  "amount_kobo": 1600000
}
```

> Maximum advance is 40% of job amount. Only callable once. Job must be in `funded` status.

**Success Response `200`:**
```json
{
  "success": true,
  "data": {
    "job_id": "job-uuid",
    "advance_drawn_kobo": 1600000,
    "remaining_in_escrow_kobo": 2400000,
    "fee_charged_kobo": 56000,
    "payout_reference": "adv_uuid"
  }
}
```

**Error Codes:**
- `ADVANCE_ALREADY_DRAWN` — advance has already been taken for this job
- `EXCEEDS_MAX_ADVANCE` — amount exceeds 40% of job value
- `JOB_NOT_FUNDED` — job escrow has not been confirmed yet
- `NOMBA_PAYOUT_FAILED` — Nomba transfer failed

---

## 4. Webhook Module

### POST /webhooks/nomba
Receive inbound payment events from Nomba.

**Auth:** `public` (verified via HMAC signature — not JWT)

> This endpoint uses `raw` body parsing (not JSON middleware) so HMAC verification works correctly.  
> Must respond `200` immediately. All processing happens asynchronously.

**Headers:**
```
nomba-signature: sha256=abc123...
Content-Type: application/json
```

**Request Body (example — transfer.successful):**
```json
{
  "requestId": "unique-event-id",
  "event": "transfer.successful",
  "data": {
    "accountRef": "job-uuid",
    "amountReceived": 4000000,
    "amountExpected": 4000000,
    "currency": "NGN",
    "narration": "Payment for generator repair",
    "transactionRef": "nomba-tx-ref"
  }
}
```

**Success Response `200`:** (immediate, no body)

**Internal Logic:**
1. Verify HMAC signature — return `401` if invalid
2. Check `requestId` against `webhook_events` table — ignore if duplicate
3. Store `requestId` in `webhook_events` with status `received`
4. Route to handler based on `event` type:
   - `transfer.successful` → compare `amountReceived` vs `amountExpected`:
     - Equal → update job to `FUNDED`, start review timer goroutine, notify both parties
     - Under → notify buyer to top up, keep job in `CREATED`
     - Over → update job to `FUNDED`, queue refund for excess amount
   - `transfer.failed` → notify buyer to retry
   - `payout.completed` → update job to `PAID_OUT`, update WorkScore
   - `payout.failed` → trigger retry logic, alert admin after 3 failures
5. Respond `200`

---

## 5. Proof Module

### POST /jobs/:id/proof
Upload proof artifact(s) for a job.

**Auth:** `merchant`

**Request Body:** `multipart/form-data`

```
artifact_type: "before_photo"     — before_photo | after_photo | file | checkin | checkout | signoff
file: <binary>
gps_lat: 6.5244
gps_lng: 3.3792
device_id: "device-uuid"
```

**Success Response `201`:**
```json
{
  "success": true,
  "data": {
    "id": "artifact-uuid",
    "job_id": "job-uuid",
    "artifact_type": "before_photo",
    "storage_url": "https://storage.googleapis.com/...",
    "content_hash": "sha256hash",
    "metadata_hash": "sha256hash",
    "gps_lat": 6.5244,
    "gps_lng": 3.3792,
    "captured_at": "2026-06-30T09:00:00Z"
  }
}
```

**Error Codes:**
- `JOB_NOT_FUNDED` — can only submit proof on funded jobs
- `INVALID_ARTIFACT_TYPE` — artifact type not accepted
- `FILE_TOO_LARGE` — max file size is 10MB
- `UPLOAD_FAILED` — GCS upload failed

---

### GET /jobs/:id/proof
Get all proof artifacts submitted for a job.

**Auth:** `authenticated`

**Success Response `200`:**
```json
{
  "success": true,
  "data": {
    "job_id": "job-uuid",
    "artifacts": [
      {
        "id": "artifact-uuid",
        "artifact_type": "before_photo",
        "storage_url": "https://storage.googleapis.com/...",
        "content_hash": "sha256hash",
        "gps_lat": 6.5244,
        "gps_lng": 3.3792,
        "captured_at": "2026-06-30T09:00:00Z"
      },
      {
        "id": "artifact-uuid-2",
        "artifact_type": "after_photo",
        "storage_url": "https://storage.googleapis.com/...",
        "content_hash": "sha256hash",
        "gps_lat": 6.5244,
        "gps_lng": 3.3792,
        "captured_at": "2026-06-30T10:30:00Z"
      }
    ]
  }
}
```

---

### POST /jobs/:id/checkin
Record dual check-in for time-based service jobs. Both parties must call this.

**Auth:** `authenticated`

**Request Body:**
```json
{
  "gps_lat": 6.5244,
  "gps_lng": 3.3792,
  "device_id": "device-uuid"
}
```

**Success Response `200`:**
```json
{
  "success": true,
  "data": {
    "job_id": "job-uuid",
    "checked_in_by": "user-uuid",
    "role": "merchant",
    "checked_in_at": "2026-06-30T08:00:00Z",
    "both_checked_in": false
  }
}
```

---

### POST /jobs/:id/checkout
Record dual check-out for time-based service jobs.

**Auth:** `authenticated`

**Request Body:**
```json
{
  "gps_lat": 6.5244,
  "gps_lng": 3.3792,
  "device_id": "device-uuid"
}
```

**Success Response `200`:**
```json
{
  "success": true,
  "data": {
    "job_id": "job-uuid",
    "checked_out_by": "user-uuid",
    "role": "merchant",
    "checked_out_at": "2026-06-30T12:00:00Z",
    "both_checked_out": true,
    "duration_minutes": 240
  }
}
```

---

## 6. Dispute Module

### POST /jobs/:id/confirm
Buyer confirms job is complete. Triggers payout to merchant.

**Auth:** `buyer`

**Request Body:** none

**Success Response `200`:**
```json
{
  "success": true,
  "data": {
    "job_id": "job-uuid",
    "status": "approved",
    "payout": {
      "amount_kobo": 3860000,
      "fee_kobo": 48000,
      "advance_deducted_kobo": 0,
      "merchant_receives_kobo": 3812000,
      "reference": "payout_uuid"
    }
  }
}
```

**Error Codes:**
- `JOB_NOT_PROOF_SUBMITTED` — proof has not been submitted yet
- `UNAUTHORIZED` — only the buyer on this job can confirm
- `NOMBA_PAYOUT_FAILED` — Nomba transfer failed

---

### POST /jobs/:id/dispute
Buyer files a dispute against a job.

**Auth:** `buyer`

**Request Body:** `multipart/form-data`

```
reason_category: "not_completed"    — not_completed | wrong_spec | quality | no_show | other
description: "The generator still does not work after repair."
evidence_file: <binary — optional>
```

**Success Response `201`:**
```json
{
  "success": true,
  "data": {
    "id": "dispute-uuid",
    "job_id": "job-uuid",
    "reason_category": "not_completed",
    "description": "The generator still does not work after repair.",
    "buyer_evidence_url": "https://storage.googleapis.com/...",
    "status": "open",
    "created_at": "2026-07-01T08:00:00Z"
  }
}
```

**Error Codes:**
- `JOB_NOT_PROOF_SUBMITTED` — can only dispute after proof is submitted
- `DISPUTE_WINDOW_EXPIRED` — review window has already expired
- `DISPUTE_ALREADY_EXISTS` — dispute already filed for this job
- `UNAUTHORIZED` — only the buyer on this job can dispute

---

### GET /disputes/:id
Get full dispute detail including evidence packet.

**Auth:** `admin`

**Success Response `200`:**
```json
{
  "success": true,
  "data": {
    "id": "dispute-uuid",
    "job_id": "job-uuid",
    "job": {
      "title": "Fix my generator",
      "amount_kobo": 4000000,
      "spec_hash": "sha256hash",
      "created_at": "2026-06-29T10:00:00Z"
    },
    "merchant": {
      "id": "merchant-uuid",
      "name": "Chidi Repairs",
      "workscore": 720,
      "dispute_history": 1
    },
    "buyer": {
      "id": "buyer-uuid",
      "name": "Emeka Obi",
      "dispute_score": 95.00
    },
    "reason_category": "not_completed",
    "description": "The generator still does not work after repair.",
    "buyer_evidence_url": "https://storage.googleapis.com/...",
    "proof_artifacts": [
      {
        "artifact_type": "before_photo",
        "storage_url": "https://storage.googleapis.com/...",
        "captured_at": "2026-06-30T09:00:00Z"
      },
      {
        "artifact_type": "after_photo",
        "storage_url": "https://storage.googleapis.com/...",
        "captured_at": "2026-06-30T10:30:00Z"
      }
    ],
    "status": "open",
    "resolution": null,
    "resolved_by": null,
    "resolved_at": null,
    "created_at": "2026-07-01T08:00:00Z"
  }
}
```

---

### GET /disputes
List all disputes. Admin only.

**Auth:** `admin`

**Query Parameters:**
```
status=open           — open | under_review | resolved (optional)
page=1
limit=20
```

**Success Response `200`:**
```json
{
  "success": true,
  "data": {
    "disputes": [
      {
        "id": "dispute-uuid",
        "job_id": "job-uuid",
        "job_title": "Fix my generator",
        "amount_kobo": 4000000,
        "reason_category": "not_completed",
        "status": "open",
        "merchant_name": "Chidi Repairs",
        "buyer_name": "Emeka Obi",
        "created_at": "2026-07-01T08:00:00Z"
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 20,
      "total": 12
    }
  }
}
```

---

### PATCH /disputes/:id/resolve
Admin resolves a dispute. Triggers payout or refund.

**Auth:** `admin`

**Request Body:**
```json
{
  "resolution": "merchant_wins",
  "notes": "Proof artifacts clearly show completed work. Buyer claim not substantiated."
}
```

> Accepted `resolution` values: `merchant_wins`, `buyer_wins`  
> `merchant_wins` → triggers payout to merchant, deducts buyer dispute score  
> `buyer_wins` → triggers refund to buyer, deducts merchant WorkScore

**Success Response `200`:**
```json
{
  "success": true,
  "data": {
    "dispute_id": "dispute-uuid",
    "job_id": "job-uuid",
    "resolution": "merchant_wins",
    "resolved_by": "admin-uuid",
    "resolved_at": "2026-07-02T14:00:00Z",
    "payout": {
      "type": "merchant_payout",
      "amount_kobo": 3860000,
      "reference": "payout_uuid"
    }
  }
}
```

**Error Codes:**
- `DISPUTE_NOT_FOUND` — dispute does not exist
- `DISPUTE_ALREADY_RESOLVED` — dispute has already been resolved
- `INVALID_RESOLUTION` — resolution value not accepted
- `NOMBA_PAYOUT_FAILED` — transfer failed on Nomba side

---

## 7. WorkScore Module

### GET /workscore/:merchantId
Get public WorkScore profile for a merchant.

**Auth:** `public`

**Success Response `200`:**
```json
{
  "success": true,
  "data": {
    "merchant_id": "merchant-uuid",
    "name": "Chidi Repairs",
    "score": 720,
    "tier": "Gold",
    "breakdown": {
      "completed_jobs": 45,
      "disputes_lost": 1,
      "earnings_tier": 3,
      "recency_bonus": 5,
      "inactivity_penalty": 0
    },
    "stats": {
      "total_jobs": 47,
      "completion_rate": 95.7,
      "avg_job_value_kobo": 2500000
    },
    "recent_jobs": [
      {
        "title": "Fix generator",
        "amount_kobo": 4000000,
        "status": "closed",
        "completed_at": "2026-06-29T10:00:00Z"
      }
    ]
  }
}
```

> Score tiers: Bronze (0–299), Silver (300–599), Gold (600–849), Platinum (850–1000)

---

### GET /workscore/:merchantId/history
Get full WorkScore event history for a merchant.

**Auth:** `merchant` (own history only) or `admin`

**Success Response `200`:**
```json
{
  "success": true,
  "data": {
    "merchant_id": "merchant-uuid",
    "current_score": 720,
    "events": [
      {
        "id": "event-uuid",
        "event_type": "job_completed",
        "score_delta": 10,
        "running_score": 720,
        "job_id": "job-uuid",
        "created_at": "2026-06-29T10:00:00Z"
      }
    ]
  }
}
```

---

## 8. Notifications Module

### GET /notifications
Get all notifications for the authenticated user.

**Auth:** `authenticated`

**Query Parameters:**
```
read=false      — filter unread only (optional)
page=1
limit=20
```

**Success Response `200`:**
```json
{
  "success": true,
  "data": {
    "notifications": [
      {
        "id": "notif-uuid",
        "type": "escrow_funded",
        "message": "Your escrow for 'Fix my generator' has been funded. You can begin work.",
        "job_id": "job-uuid",
        "read": false,
        "created_at": "2026-06-29T11:30:00Z"
      }
    ],
    "unread_count": 3,
    "pagination": {
      "page": 1,
      "limit": 20,
      "total": 12
    }
  }
}
```

---

### PATCH /notifications/:id/read
Mark a single notification as read.

**Auth:** `authenticated`

**Request Body:** none

**Success Response `200`:**
```json
{
  "success": true,
  "data": {
    "id": "notif-uuid",
    "read": true
  }
}
```

---

### PATCH /notifications/read-all
Mark all notifications as read for the authenticated user.

**Auth:** `authenticated`

**Request Body:** none

**Success Response `200`:**
```json
{
  "success": true,
  "data": {
    "updated": 5
  }
}
```

---

## 9. Admin Module

### GET /admin/stats
Get platform-wide stats for the admin dashboard.

**Auth:** `admin`

**Success Response `200`:**
```json
{
  "success": true,
  "data": {
    "total_escrow_held_kobo": 125000000,
    "jobs_in_dispute": 4,
    "open_disputes": 4,
    "total_jobs": 312,
    "completed_jobs": 289,
    "chargeback_rate": 1.4,
    "total_merchants": 87,
    "total_buyers": 201,
    "revenue_this_month_kobo": 4500000
  }
}
```

---

### GET /admin/merchants
List all merchants with health metrics.

**Auth:** `admin`

**Query Parameters:**
```
workscore_tier=gold     — bronze | silver | gold | platinum (optional)
page=1
limit=20
```

**Success Response `200`:**
```json
{
  "success": true,
  "data": {
    "merchants": [
      {
        "id": "merchant-uuid",
        "name": "Chidi Repairs",
        "email": "chidi@example.com",
        "phone": "+2348012345678",
        "workscore": 720,
        "tier": "Gold",
        "total_jobs": 47,
        "disputes_lost": 1,
        "total_earnings_kobo": 105000000,
        "created_at": "2026-06-01T10:00:00Z"
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 20,
      "total": 87
    }
  }
}
```

---

### GET /admin/workscore/distribution
Get WorkScore tier distribution for charts.

**Auth:** `admin`

**Success Response `200`:**
```json
{
  "success": true,
  "data": {
    "bronze": 12,
    "silver": 34,
    "gold": 31,
    "platinum": 10
  }
}
```

---

### GET /admin/reconciliation/log
Get the latest reconciliation job output.

**Auth:** `admin`

**Success Response `200`:**
```json
{
  "success": true,
  "data": {
    "last_run_at": "2026-07-01T00:00:00Z",
    "status": "completed",
    "transactions_checked": 312,
    "orphans_found": 0,
    "amount_drift_found": 0,
    "alerts": []
  }
}
```

---

## 10. Health Check

### GET /health
Health check endpoint for judges and monitoring.

**Auth:** `public`

**Success Response `200`:**
```json
{
  "success": true,
  "data": {
    "status": "ok",
    "version": "1.0.0",
    "database": "connected",
    "nomba_api": "reachable",
    "timestamp": "2026-06-29T10:00:00Z"
  }
}
```

---

## 11. Complete Route Index

| Method | Route | Auth | Module |
|---|---|---|---|
| POST | /auth/otp/send | public | Auth |
| POST | /auth/otp/verify | public | Auth |
| POST | /auth/token/refresh | public | Auth |
| POST | /auth/logout | authenticated | Auth |
| GET | /auth/me | authenticated | Auth |
| PATCH | /auth/me | authenticated | Auth |
| POST | /auth/admin/login | public | Auth |
| POST | /jobs | merchant | Jobs |
| GET | /jobs | authenticated | Jobs |
| GET | /jobs/:id | authenticated | Jobs |
| POST | /jobs/:id/accept | buyer | Jobs |
| GET | /jobs/:id/share-link | merchant | Jobs |
| POST | /jobs/:id/complete | merchant | Jobs |
| GET | /jobs/:id/escrow | authenticated | Escrow |
| POST | /jobs/:id/advance | merchant | Escrow |
| POST | /webhooks/nomba | public (HMAC) | Webhook |
| POST | /jobs/:id/proof | merchant | Proof |
| GET | /jobs/:id/proof | authenticated | Proof |
| POST | /jobs/:id/checkin | authenticated | Proof |
| POST | /jobs/:id/checkout | authenticated | Proof |
| POST | /jobs/:id/confirm | buyer | Dispute |
| POST | /jobs/:id/dispute | buyer | Dispute |
| GET | /disputes/:id | admin | Dispute |
| GET | /disputes | admin | Dispute |
| PATCH | /disputes/:id/resolve | admin | Dispute |
| GET | /workscore/:merchantId | public | WorkScore |
| GET | /workscore/:merchantId/history | merchant/admin | WorkScore |
| GET | /notifications | authenticated | Notifications |
| PATCH | /notifications/:id/read | authenticated | Notifications |
| PATCH | /notifications/read-all | authenticated | Notifications |
| GET | /admin/stats | admin | Admin |
| GET | /admin/merchants | admin | Admin |
| GET | /admin/workscore/distribution | admin | Admin |
| GET | /admin/reconciliation/log | admin | Admin |
| GET | /health | public | Health |

---

## 12. Missing Database Table — Notifications

Add this table to your MySQL schema. It is not in the original blueprint:

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

## 13. Missing Database Table — Webhook Events

Add this table for webhook idempotency. Store every incoming Nomba `requestId` here:

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

*NombaWorkReceipt API Specification v1.0 — Reed Breed Technologies — June 2026*
