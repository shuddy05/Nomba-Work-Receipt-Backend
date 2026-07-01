-- Combined MySQL Schema for NombaWorkReceipt

SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS webhook_events;
DROP TABLE IF EXISTS notifications;
DROP TABLE IF EXISTS workscore_events;
DROP TABLE IF EXISTS disputes;
DROP TABLE IF EXISTS checkins;
DROP TABLE IF EXISTS proof_artifacts;
DROP TABLE IF EXISTS payouts;
DROP TABLE IF EXISTS escrow_accounts;
DROP TABLE IF EXISTS jobs;
DROP TABLE IF EXISTS refresh_tokens;
DROP TABLE IF EXISTS otp_codes;
DROP TABLE IF EXISTS users;

SET FOREIGN_KEY_CHECKS = 1;

-- 001_create_users.sql
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
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 002_create_jobs.sql
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

-- 003_create_escrow.sql
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
  FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE CASCADE
);

CREATE TABLE payouts (
  id VARCHAR(36) PRIMARY KEY,
  job_id VARCHAR(36) NOT NULL,
  `type` ENUM('advance', 'final_payout', 'refund') NOT NULL,
  amount_kobo BIGINT NOT NULL,
  fee_kobo BIGINT DEFAULT 0,
  recipient_account_number VARCHAR(20),
  recipient_bank_code VARCHAR(10),
  recipient_account_name VARCHAR(255),
  merchant_tx_ref VARCHAR(100) NOT NULL UNIQUE,
  nomba_transfer_status ENUM('pending', 'successful', 'failed') DEFAULT 'pending',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE CASCADE
);

-- 004_create_proof_artifacts.sql
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
  FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE CASCADE
);

CREATE TABLE checkins (
  id VARCHAR(36) PRIMARY KEY,
  job_id VARCHAR(36) NOT NULL,
  user_id VARCHAR(36) NOT NULL,
  `type` ENUM('checkin', 'checkout') NOT NULL,
  gps_lat DECIMAL(10,7),
  gps_lng DECIMAL(10,7),
  device_id VARCHAR(100),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 005_create_disputes.sql
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
  FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE CASCADE,
  FOREIGN KEY (buyer_id) REFERENCES users(id),
  FOREIGN KEY (resolved_by) REFERENCES users(id)
);

-- 006_create_workscore_events.sql
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
  FOREIGN KEY (merchant_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE SET NULL
);

-- 007_create_notifications.sql
CREATE TABLE notifications (
  id VARCHAR(36) PRIMARY KEY,
  user_id VARCHAR(36) NOT NULL,
  job_id VARCHAR(36),
  `type` ENUM(
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
  `read` BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE SET NULL
);

-- 008_create_webhook_events.sql
CREATE TABLE webhook_events (
  id VARCHAR(36) PRIMARY KEY,
  request_id VARCHAR(200) UNIQUE NOT NULL,
  event_type VARCHAR(100) NOT NULL,
  payload JSON NOT NULL,
  status ENUM('received', 'processed', 'failed') DEFAULT 'received',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
