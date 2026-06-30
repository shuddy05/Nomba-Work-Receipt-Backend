# NOMBA WORKRECEIPT — Product Blueprint

*Proof-of-Work Escrow Payments for Nigeria's Service Economy*

**Product Blueprint & Technical Specification**

**Nomba x DevCareer Hackathon 2026**

Submission Period: July 1 – July 7, 2026
Demo Day: July 18, 2026

Prepared by: Reed Breed Technologies
Lagos, Nigeria | June 2026

> **Stack note (updated):** This blueprint has been revised from its original React Native + PostgreSQL/Supabase + Redis architecture to **Flutter + MySQL (Hostinger) + Go goroutines (no Redis)**, with three backend gaps corrected: bank account lookup before every payout, over/under-payment handling on virtual accounts, and a nightly reconciliation job. See Section 8 (Technology Stack) and Section 6.1 (Module Map) for the corrected details. Email OTP via Brevo replaces SMS-based auth — see the companion backend build spec for full implementation rules.

---

## 1. Executive Summary

Nigeria's informal service economy processes an estimated ₦47 trillion in annual transactions across mechanics, tailors, caterers, cleaners, tutors, freelancers, and skilled tradespeople. Despite this scale, the overwhelming majority of these transactions have no digital paper trail, no payment protection, and no dispute resolution mechanism beyond word of mouth.

Nomba WorkReceipt is a proof-of-work escrow and trust infrastructure layer built on Nomba's API stack. It enables any Nigerian service merchant to create a structured job agreement, lock buyer funds in escrow via a Nomba virtual account, collect tamper-evident proof of work completion, and receive payment automatically when the buyer confirms — or when the review window expires without dispute.

The system introduces WorkScore: a verified merchant reputation and earnings history derived from completed jobs. WorkScore is the credit primitive Nigeria's service economy is missing — the data layer that enables Nomba (or lending partners) to underwrite micro-loans, offer advance-on-escrow financing, and extend BNPL to buyers, all grounded in actual verified work history rather than bank statements.

|                                                                                                                                |
|--------------------------------------------------------------------------------------------------------------------------------|
| ***"Nomba moves money. WorkReceipt makes sure it only moves when work is real — and turns every job into a credit history."*** |

WorkReceipt is not a marketplace. It is the trust and proof infrastructure that every existing marketplace, cooperative, and service platform in Nigeria lacks and can embed via a single SDK integration. This positions WorkReceipt as payment rails for the informal economy — defensible, data-driven, and impossible to replicate without the verified job history it accumulates over time.

### 1.1. Hackathon Alignment

|                     |                                                                        |
|---------------------|------------------------------------------------------------------------|
| **Criterion**       | **WorkReceipt Position**                                               |
| Track               | Infrastructure Track — Managed Escrow + Virtual Account System         |
| Nomba APIs Used     | Virtual Accounts, Webhooks, Payout API, Checkout, Tokenized Flows      |
| Problem Solved      | Trust/dispute hell + cashflow gaps + offline-to-online proof           |
| Differentiator      | Data layer for merchant credit scoring — no other team will build this |
| Post-Hackathon Path | Nomba Developer Partner Program + independent SaaS revenue             |

## 2. Problem Statement

Three structural problems prevent Nigeria's ₦47 trillion informal service economy from going digital at scale. Each problem is distinct. Together, they form a trust gap that no existing fintech product has closed.

### 2.1. Trust and Dispute Hell

When a customer pays a mechanic ₦40,000 to fix an AC and later claims 'I didn't get the service,' neither party has verifiable evidence. The merchant has WhatsApp messages. The buyer has a bank transfer receipt. Nomba's support team has two conflicting stories. Chargebacks occur. Merchants lose money they earned. Buyers lose trust in digital payments.

Industry data indicates that 40% of POS chargebacks in Nigeria are for 'service not rendered.' This is not a fraud problem — it is an evidence problem. There is no structured record of what was agreed, what was delivered, and when.

### 2.2. Cashflow Gaps for Service Businesses

A tailor takes a ₦60,000 order. She needs ₦15,000 in fabric today. The customer pays on delivery — two weeks away. No bank will lend ₦15,000 against a WhatsApp conversation. No fintech can underwrite her because she has no verified revenue history. She borrows from a cooperative at 10% per week or turns down the job.

Revenue-based financing exists for e-commerce merchants with Paystack or Flutterwave data. It does not exist for offline service businesses because there is no data layer to underwrite against. WorkReceipt creates that data layer.

### 2.3. Offline-to-Online Proof Gap

90% of Nigeria's GDP is generated in offline service transactions. Nomba cannot offer split-pay, micro-loans, or dynamic MDR to merchants it cannot verify. Without proof that a haircut happened, a car was repaired, or code was delivered, every underwriting decision is a guess.

WorkReceipt solves this by creating a structured, timestamped, tamper-evident record for every job — appropriate to the service type — that feeds into a merchant WorkScore. This is the data primitive that unlocks an entirely new category of fintech products on top of Nomba's infrastructure.

## 3. Product Overview

WorkReceipt is a multi-channel escrow and proof-of-work platform with five surface areas: a web application, a mobile application (Android), a USSD/SMS channel, a Nomba-facing analytics dashboard, and a white-label marketplace SDK.

### 3.1. Core Value Proposition

- For merchants: Get paid with confidence. Proof of work protects you from false disputes. WorkScore builds your reputation and unlocks credit.

- For buyers: Pay without risk. Funds are locked until work is done. Dispute window gives you time to verify before money leaves.

- For Nomba: A verified job graph across Nigeria's informal economy. Underwrite loans. Reduce chargebacks. Expand merchant base into previously unbanked service sectors.

- For marketplace partners: Drop-in trust infrastructure. Embed escrow in one SDK call. Stop losing users to payment disputes.

### 3.2. Feature List (Full)

|        |                                              |                                                                                                                                                                                           |
|--------|----------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **\#** | **Feature**                                  | **Description**                                                                                                                                                                           |
| 1      | **Job Creation & Spec Locking**              | Merchant and buyer agree job title, description, amount, proof type, and review window before any money moves. Spec is cryptographically hashed and immutable after both parties confirm. |
| 2      | **Escrow Funding via Nomba Virtual Account** | Buyer receives a dedicated Nomba virtual account per job. Payment via normal bank transfer triggers a webhook that locks funds and notifies both parties.                                 |
| 3      | **Proof Submission Layer**                   | In-app camera (no gallery) with GPS + timestamp + device ID baked in at capture. File upload for digital work with hash on arrival. Dual check-in/out for time-based services.            |
| 4      | **Buyer Review Window + Auto-Release**       | Configurable per job type (24hrs to 7 days). Buyer confirms or disputes within window. Silence = auto-release. Timer logic runs server-side — no client dependency.                       |
| 5      | **Dispute Escalation with Evidence Packet**  | Active dispute triggers auto-assembly of structured evidence: spec, proof artifacts, timeline, both party signatures. Sent to Nomba review team for human arbitration.                    |
| 6      | **WorkScore Merchant Profile**               | Every resolved job updates merchant's public WorkScore: verified earnings, job volume, dispute rate, service categories. Shareable as a link. Visible to buyers before hiring.            |
| 7      | **Materials Advance on Escrow**              | Merchant draws a partial advance (up to 40% of job value) against locked escrow funds immediately after funding. Remaining balance releases on proof approval.                            |
| 8      | **WorkScore → Credit Line**                  | WorkScore history is the underwriting signal for micro-loans and BNPL products. Nomba or lending partners access via API to extend credit to verified merchants and buyers.               |
| 9      | **Buyer Dispute Reputation**                 | Buyers who dispute and lose accumulate a dispute score. Merchants can see buyer dispute history before accepting jobs. Deters frivolous disputes without requiring legal action.          |
| 10     | **Marketplace SDK / White-Label Escrow**     | JavaScript SDK for third-party platforms. One embed turns any checkout into WorkReceipt-powered escrow. Webhook-native. Full documentation and sandbox environment.                       |
| 11     | **USSD + SMS Fallback Channel**              | Full core flow accessible via USSD for feature phone users. Merchant marks complete via dial-in. Buyer receives SMS prompt. Auto-release fires regardless of channel.                     |

## 4. Screen Inventory

WorkReceipt spans five surface areas. Total screen count across all surfaces: 38 screens.

### 4.1. Web Application (14 Screens)

|        |                                |                                                                                                                                                      |
|--------|--------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------|
| **\#** | **Screen**                     | **Description**                                                                                                                                      |
| W1     | **Landing / Marketing Page**   | Hero with tagline, product explainer, WorkScore preview, partner logos, CTA to register as merchant or buyer.                                        |
| W2     | **Merchant Onboarding**        | Registration form: name, business category, phone, BVN (optional), Nomba account link. Sets default proof type per service category.                 |
| W3     | **Buyer Onboarding**           | Lightweight registration: name, phone, NIN optional. Buyer dispute history initialized at zero.                                                      |
| W4     | **Merchant Dashboard**         | Overview: active jobs, pending payouts, WorkScore, MRR (for recurring clients), recent job history, quick actions.                                   |
| W5     | **Create Job**                 | Step-by-step job creation: title, description, amount, proof type selection, review window selector, buyer phone input. Preview spec before locking. |
| W6     | **Job Detail — Merchant View** | Full job status: spec, escrow funding status, proof submissions, timer countdown, payout status. Dispute flag visible if raised.                     |
| W7     | **Proof Submission**           | Upload interface: camera capture for physical, file upload for digital, check-in confirmation for time-based. Hash displayed post-upload.            |
| W8     | **WorkScore Profile (Public)** | Merchant's public page: verified jobs count, earnings range, dispute rate, service categories, job history (redacted), shareable link.               |
| W9     | **Buyer Dashboard**            | Active jobs as buyer, payment history, dispute history, dispute reputation score.                                                                    |
| W10    | **Job Detail — Buyer View**    | Spec review, escrow funding prompt with virtual account details, timer, confirm/dispute buttons, evidence preview.                                   |
| W11    | **Dispute Filing**             | Guided dispute form: reason category, description, optional buyer evidence upload. Confirms evidence packet assembly.                                |
| W12    | **Advance on Escrow**          | Merchant draws partial advance: slider showing max drawable amount, instant transfer confirmation, remaining balance display.                        |
| W13    | **Marketplace Partner Portal** | SDK key management, webhook configuration, integration docs, transaction volume dashboard, revenue share tracking.                                   |
| W14    | **Nomba Admin Dashboard**      | Real-time: total escrow held, jobs in dispute, WorkScore distribution, top merchants by verified volume, chargeback rate comparison.                 |

### 4.2. Mobile Application — Android (14 Screens)

|        |                                       |                                                                                                                               |
|--------|---------------------------------------|-------------------------------------------------------------------------------------------------------------------------------|
| **\#** | **Screen**                            | **Description**                                                                                                               |
| M1     | **Splash / Onboarding**               | Brand intro, value prop in three slides, CTA to register or log in.                                                           |
| M2     | **Merchant Registration**             | Mobile-optimized onboarding. Email OTP verification (via Brevo). Camera permission request for proof capture.                             |
| M3     | **Home / Dashboard**                  | Job cards: active, pending proof, completed. WorkScore badge. Quick-create FAB.                                               |
| M4     | **Create Job Flow**                   | Multi-step bottom sheet: job details → proof type → amount → share link. One-tap to copy job link for WhatsApp sharing.       |
| M5     | **Job Camera — Physical Proof**       | Full-screen camera with GPS overlay, timestamp watermark, in-app only (no gallery access). Before and after capture sequence. |
| M6     | **Job Camera — After Capture Review** | Preview captured proof, confirm or retake. Hash computation shown on confirm.                                                 |
| M7     | **Job Status Screen**                 | Live timer, escrow status pill, proof upload status, payout ETA. Pull-to-refresh.                                             |
| M8     | **Buyer Job Link Landing**            | Buyer taps shared link. Reviews spec, sees virtual account details to fund, confirms understanding of review window.          |
| M9     | **Buyer Confirm / Dispute**           | Post-completion prompt: large confirm button, dispute option with reason selector. Timer countdown visible.                   |
| M10    | **WorkScore Profile**                 | Personal WorkScore card with shareable link. Verified jobs, dispute rate, categories. WhatsApp share button.                  |
| M11    | **Advance on Escrow**                 | Simple slider interface to draw materials advance. Instant confirmation. Balance updated in real-time.                        |
| M12    | **Notifications Center**              | All job events: escrow funded, proof submitted, review window expiring, payout released, dispute filed.                       |
| M13    | **Dispute Detail**                    | Evidence packet view: spec, merchant proof, timeline. Status: under review / resolved.                                        |
| M14    | **Settings**                          | Linked Nomba account, default proof type, review window preference, notification settings, USSD PIN setup.                    |

### 4.3. USSD Flow Screens (5 States)

|        |                            |                                                                                                         |
|--------|----------------------------|---------------------------------------------------------------------------------------------------------|
| **\#** | **USSD State**             | **Description**                                                                                         |
| U1     | **Main Menu**              | Dial \*XXX#: 1) My Jobs 2) Mark Complete 3) Check Payout 4) Dispute Status                              |
| U2     | **Job List**               | Lists active jobs by ID and short title. Select by number.                                              |
| U3     | **Mark Complete**          | Confirm job completion. Triggers proof-submitted event. Buyer SMS sent automatically.                   |
| U4     | **Buyer Confirmation SMS** | Buyer receives: 'Job \[ID\] marked complete. Reply 1 to confirm, 2 to dispute. Auto-releases in 72hrs.' |
| U5     | **Payout Confirmation**    | Merchant receives SMS: 'Job \[ID\] approved. ₦XX,XXX releasing to Nomba account. WorkScore updated.'    |

### 4.4. Marketplace SDK (5 Integration States)

|        |                             |                                                                                                                  |
|--------|-----------------------------|------------------------------------------------------------------------------------------------------------------|
| **\#** | **State**                   | **Description**                                                                                                  |
| S1     | **Embed Checkout Widget**   | Partner platform loads WorkReceipt JS widget. Buyer pays into escrow without leaving partner site.               |
| S2     | **Job Created Webhook**     | Partner receives webhook: job ID, escrow status, expected proof type, review window.                             |
| S3     | **Proof Submitted Webhook** | Partner notified when merchant submits proof. Can surface confirmation UI to buyer.                              |
| S4     | **Resolution Webhook**      | Partner receives: approved/disputed/auto-released. Can update order status, release listing, or flag for review. |
| S5     | **WorkScore API**           | Partner queries merchant WorkScore before surfacing them in search results. Verified badge served from API.      |

## 5. User Flows

### 5.1. Primary Happy Path — Physical Service Job

1.  1\. Merchant opens app → taps 'Create Job'

2.  2\. Enters: 'Fix car AC', ₦40,000, Proof Type: Photo, Review Window: 72hrs

3.  3\. Spec is hashed and locked. Job link generated.

4.  4\. Merchant shares link via WhatsApp to buyer.

5.  5\. Buyer opens link → reviews spec → sees virtual account number + bank name.

6.  6\. Buyer sends ₦40,000 via bank transfer to virtual account.

7.  7\. Nomba webhook fires → escrow confirmed → both parties notified.

8.  8\. Merchant draws ₦12,000 materials advance (optional).

9.  9\. Merchant does the work.

10. 10\. Merchant opens app → takes BEFORE photo in-app (GPS + timestamp embedded).

11. 11\. Does the work. Takes AFTER photo in-app.

12. 12\. Marks job complete. Both photos + hash submitted.

13. 13\. Buyer receives push notification: 'Job complete. Confirm or dispute within 72hrs.'

14. 14\. Buyer opens app → reviews photos → taps Confirm.

15. 15\. Backend calls /transfers/bank/lookup → confirms merchant account name → calls Nomba Payout API → ₦28,000 balance (minus advance) sent to merchant bank account.

16. 16\. WorkScore updated. Job archived.

### 5.2. Auto-Release Path

17. 1–12. Same as above.

18. 13\. Buyer receives notification. Takes no action.

19. 14\. 72-hour server-side timer expires.

20. 15\. System calls /transfers/bank/lookup → confirms merchant account → auto-calls Nomba Payout API. Funds released without buyer action.

21. 16\. Both parties notified via SMS and push.

22. 17\. WorkScore updated.

### 5.3. Dispute Flow

23. 1\. Buyer taps 'Dispute' within 72-hour window.

24. 2\. Reason category selected: 'Work not completed as agreed.'

25. 3\. Optional: buyer uploads own evidence.

26. 4\. Evidence packet auto-assembled: locked spec, merchant proof, buyer evidence, full event timeline.

27. 5\. Job flagged in Nomba admin dashboard. Escrow hold extended.

28. 6\. Nomba human reviewer opens packet — has everything structured, no back-and-forth needed.

29. 7\. Decision made: approved for merchant OR refunded to buyer.

30. 8\. Loser's reputation score (merchant dispute rate OR buyer dispute score) updated.

31. 9\. Both parties notified. Job closed.

### 5.4. USSD Flow — Feature Phone Merchant

32. 1\. Merchant dials \*XXX\*JobID#

33. 2\. Menu displayed: 1) Mark Complete 2) Check Status 3) Draw Advance

34. 3\. Merchant selects 1 → 'Confirm job \[AC Repair – Emeka\] complete? 1=Yes 2=No'

35. 4\. Merchant presses 1.

36. 5\. System triggers proof-submitted event (photo waived for USSD — functional sign-off only).

37. 6\. Buyer receives SMS: 'Your job \[AC Repair\] is marked complete. Reply 1 to confirm or 2 to dispute. Funds auto-release in 72hrs if no reply.'

38. 7\. Buyer replies 1 → payout triggered instantly.

39. 8\. Merchant receives SMS confirmation with payout amount.

### 5.5. Marketplace SDK Integration Flow

40. 1\. Partner platform loads WorkReceipt JS SDK with API key.

41. 2\. When buyer proceeds to checkout, SDK widget renders escrow payment UI inline.

42. 3\. Buyer funds escrow. Webhook sent to partner and WorkReceipt.

43. 4\. Merchant notified (via partner platform) that funds are locked.

44. 5\. Merchant completes job on partner platform. Marks done.

45. 6\. WorkReceipt proof layer activates (configured per partner's service category).

46. 7\. Resolution webhook sent to partner: approved/disputed/auto-released.

47. 8\. Partner updates order status. WorkScore API queried for badge update.

## 6. System Modules & Architecture

### 6.1. Module Map

|                          |                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
|--------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Module**               | **Responsibilities**                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| **Auth Module**          | Email OTP via Brevo, JWT issuance, session management, role assignment (merchant/buyer/partner/admin).                                                                                                                                                                                                                                                                                                                                                                                      |
| **Job Module**           | Job creation, spec hashing, state machine (created → funded → in_progress → proof_submitted → approved/disputed → closed).                                                                                                                                                                                                                                                                                                                                                        |
| **Escrow Module**        | Nomba virtual account provisioning per job. Funding detection via webhook — compares amountReceived to amountExpected: under-payment surfaces prompt to buyer to top up; over-payment queues refund of excess. Advance drawdown logic. Payout trigger on resolution: calls /transfers/bank/lookup to verify merchant account name, then initiates /transfers/bank. Reconciliation cron runs nightly against /transactions endpoint to catch orphan transactions and amount drift. |
| **Proof Module**         | In-app camera capture with metadata injection, file upload with hash computation, dual check-in signature handling, proof storage in GCS.                                                                                                                                                                                                                                                                                                                                         |
| **Review Timer Module**  | Server-side countdown per job. Configurable per job type. Auto-release trigger on expiry. Idempotent — survives restarts.                                                                                                                                                                                                                                                                                                                                                         |
| **Dispute Module**       | Dispute filing, evidence packet assembly, escalation routing, resolution recording, reputation score updates.                                                                                                                                                                                                                                                                                                                                                                     |
| **WorkScore Engine**     | Score computation: verified job count, dispute rate, earnings volume, recency weighting. Public profile generation. Credit API endpoint.                                                                                                                                                                                                                                                                                                                                          |
| **Webhook Relay Module** | Outbound webhooks to marketplace partners. Retry logic with exponential backoff. Delivery confirmation. Event log.                                                                                                                                                                                                                                                                                                                                                                |
| **Notification Module**  | Push (FCM), SMS (Termii/Africa's Talking), WhatsApp (Meta API), USSD (Africa's Talking). Unified event-to-channel routing.                                                                                                                                                                                                                                                                                                                                                        |
| **Advance Module**       | Drawdown eligibility check (escrow confirmed + advance not yet drawn), partial payout via Nomba API, remaining balance tracking.                                                                                                                                                                                                                                                                                                                                                  |
| **Admin Module**         | Nomba-facing dashboard: dispute queue, WorkScore analytics, escrow ledger, merchant health metrics.                                                                                                                                                                                                                                                                                                                                                                               |
| **SDK Module**           | JS embeddable widget, partner API key management, webhook configuration, sandbox environment.                                                                                                                                                                                                                                                                                                                                                                                     |

### 6.2. Job State Machine

- CREATED → (buyer funds escrow) → FUNDED

- FUNDED → (merchant draws advance) → ADVANCE_DRAWN \[optional branch\]

- FUNDED / ADVANCE_DRAWN → (merchant marks complete + proof) → PROOF_SUBMITTED

- PROOF_SUBMITTED → (buyer confirms) → APPROVED → PAID_OUT → CLOSED

- PROOF_SUBMITTED → (review window expires, no action) → AUTO_RELEASED → PAID_OUT → CLOSED

- PROOF_SUBMITTED → (buyer disputes within window) → DISPUTED → UNDER_REVIEW → APPROVED or REFUNDED → CLOSED

### 6.3. Proof Type Decision Tree

|                               |                      |                                                                                     |
|-------------------------------|----------------------|-------------------------------------------------------------------------------------|
| **Service Category**          | **Proof Type**       | **Mechanism**                                                                       |
| **Physical transformation**   | Photo diff           | Before + after in-app camera. GPS + timestamp embedded. No gallery access.          |
| **Digital / tech work**       | Artifact upload      | File or repo link submitted. SHA-256 hash computed and stored on submission.        |
| **Time-based services**       | Dual check-in/out    | Both parties sign session start and end via app or USSD. Duration logged.           |
| **Custom orders / tailoring** | Spec-locked delivery | Spec hashed at creation. Delivery compared against locked spec in dispute.          |
| **Repairs / functional**      | Functional sign-off  | Buyer taps 'It works' post-completion. Timestamp recorded. Waivable for USSD users. |

## 7. Database Schema

### 7.1. Core Tables

**users**

|                      |                    |                                          |
|----------------------|--------------------|------------------------------------------|
| **Field**            | **Type**           | **Notes**                                |
| **id**               | UUID PK            | Primary identifier                       |
| **phone**            | VARCHAR(15) UNIQUE | Nigerian phone number — profile/contact field, not used for login |
| **email**            | VARCHAR(255) UNIQUE | Verified via OTP (Brevo) — primary login identifier |
| **name**             | VARCHAR(200)       | Display name                             |
| **role**             | ENUM               | merchant \| buyer \| partner \| admin    |
| **bvn_hash**         | VARCHAR(64)        | SHA-256 of BVN — never stored plain      |
| **nomba_account_id** | VARCHAR(100)       | Linked Nomba account reference           |
| **dispute_score**    | DECIMAL(5,2)       | Buyer dispute reputation. Starts at 100. |
| **created_at**       | TIMESTAMP          |                                          |
| **updated_at**       | TIMESTAMP          |                                          |

**jobs**

|                         |                 |                                                                                                     |
|-------------------------|-----------------|-----------------------------------------------------------------------------------------------------|
| **Field**               | **Type**        | **Notes**                                                                                           |
| **id**                  | UUID PK         |                                                                                                     |
| **merchant_id**         | UUID FK → users |                                                                                                     |
| **buyer_id**            | UUID FK → users | Nullable until buyer accepts link                                                                   |
| **title**               | VARCHAR(200)    |                                                                                                     |
| **description**         | TEXT            |                                                                                                     |
| **amount_kobo**         | BIGINT          | Amount in kobo — no float arithmetic                                                                |
| **advance_drawn_kobo**  | BIGINT          | Amount drawn as materials advance. Default 0.                                                       |
| **proof_type**          | ENUM            | photo \| artifact \| dual_checkin \| spec_locked \| functional_signoff                              |
| **review_window_hours** | INT             | 24 \| 72 \| 168 (7 days)                                                                            |
| **status**              | ENUM            | created \| funded \| proof_submitted \| approved \| disputed \| auto_released \| paid_out \| closed |
| **spec_hash**           | VARCHAR(64)     | SHA-256 of locked spec JSON                                                                         |
| **virtual_account_ref** | VARCHAR(100)    | Nomba virtual account reference for this job                                                        |
| **funded_at**           | TIMESTAMP       | When escrow confirmed by webhook                                                                    |
| **proof_submitted_at**  | TIMESTAMP       |                                                                                                     |
| **review_deadline_at**  | TIMESTAMP       | funded_at + review_window                                                                           |
| **resolved_at**         | TIMESTAMP       |                                                                                                     |
| **resolution**          | ENUM            | approved \| refunded \| auto_released                                                               |
| **created_at**          | TIMESTAMP       |                                                                                                     |

**proof_artifacts**

|                   |                 |                                                                       |
|-------------------|-----------------|-----------------------------------------------------------------------|
| **Field**         | **Type**        | **Notes**                                                             |
| **id**            | UUID PK         |                                                                       |
| **job_id**        | UUID FK → jobs  |                                                                       |
| **artifact_type** | ENUM            | before_photo \| after_photo \| file \| checkin \| checkout \| signoff |
| **storage_url**   | TEXT            | GCS URL                                                               |
| **content_hash**  | VARCHAR(64)     | SHA-256 of file content                                               |
| **metadata_hash** | VARCHAR(64)     | SHA-256 of {gps_lat, gps_lng, device_id, timestamp}                   |
| **gps_lat**       | DECIMAL(9,6)    |                                                                       |
| **gps_lng**       | DECIMAL(9,6)    |                                                                       |
| **device_id**     | VARCHAR(200)    |                                                                       |
| **captured_at**   | TIMESTAMP       | Server-assigned on upload — not client-provided                       |
| **submitted_by**  | UUID FK → users |                                                                       |

**disputes**

|                        |                 |                                                            |
|------------------------|-----------------|------------------------------------------------------------|
| **Field**              | **Type**        | **Notes**                                                  |
| **id**                 | UUID PK         |                                                            |
| **job_id**             | UUID FK → jobs  |                                                            |
| **raised_by**          | UUID FK → users | Buyer ID                                                   |
| **reason_category**    | ENUM            | not_completed \| wrong_spec \| quality \| no_show \| other |
| **description**        | TEXT            |                                                            |
| **buyer_evidence_url** | TEXT            | Optional buyer-uploaded evidence                           |
| **status**             | ENUM            | open \| under_review \| resolved                           |
| **resolution**         | ENUM            | merchant_wins \| buyer_wins                                |
| **resolved_by**        | UUID FK → users | Admin reviewer ID                                          |
| **resolved_at**        | TIMESTAMP       |                                                            |
| **created_at**         | TIMESTAMP       |                                                            |

**workscore_events**

|                   |                 |                                                                |
|-------------------|-----------------|----------------------------------------------------------------|
| **Field**         | **Type**        | **Notes**                                                      |
| **id**            | UUID PK         |                                                                |
| **merchant_id**   | UUID FK → users |                                                                |
| **job_id**        | UUID FK → jobs  |                                                                |
| **event_type**    | ENUM            | job_completed \| dispute_won \| dispute_lost \| advance_repaid |
| **score_delta**   | DECIMAL(5,2)    | Points added or subtracted                                     |
| **running_score** | DECIMAL(5,2)    | Score after this event                                         |
| **created_at**    | TIMESTAMP       |                                                                |

## 8. Technology Stack

|                        |                                                    |                                                                                                                                                                                                      |
|------------------------|----------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Layer**              | **Technology**                                     | **Rationale**                                                                                                                                                                                        |
| **Frontend (Web)**     | Next.js 14, TypeScript, Tailwind CSS               | Reed's primary stack. Fast SSR for WorkScore public profiles. SEO for organic merchant discovery.                                                                                                    |
| **Frontend (Mobile)**  | Flutter                                            | Single codebase for Android MVP. Flutter Camera plugin for GPS-stamped in-app capture. Push notifications via Firebase Cloud Messaging.                                                              |
| **Backend API**        | Go (Fiber framework)                               | Reed's backend stack. High throughput for webhook processing. Minimal memory footprint for escrow timer jobs.                                                                                        |
| **Database**           | MySQL                                              | ACID compliance for financial transactions. Familiar to the team. Hosted on Hostinger for the hackathon build, migrating to DigitalOcean Managed MySQL post-hackathon.                              |
| **File Storage**       | Google Cloud Storage                               | Proof artifact storage. Signed URLs for time-limited access. Bucket-level immutability for legal hold.                                                                                               |
| **Background Jobs**    | Go goroutines + DB-backed job table                | Review window countdown timers managed via Go goroutines with persistent MySQL-backed job state. Webhook retry queue with exponential backoff. Idempotency enforced via unique constraints in MySQL. |
| **Payments**           | Nomba API (Virtual Accounts, Webhooks, Payout API) | Core infrastructure layer. Virtual account per job. Webhook for funding detection. Payout on resolution.                                                                                             |
| **Notifications**      | Brevo (Email OTP), Africa's Talking (USSD), FCM (Push)  | Brevo for transactional email OTP delivery. Africa's Talking for USSD session management. FCM for mobile push.                                                                                                 |
| **Hashing / Security** | SHA-256 (Go stdlib), HMAC webhook verification     | Content hashing for proof artifacts. HMAC-SHA256 for Nomba webhook signature verification.                                                                                                           |
| **Hosting**            | Render (backend) + Hostinger Managed MySQL         | Render for fast GitHub-connected deploys with automatic HTTPS, no manual DevOps. Hostinger for MySQL, remote access enabled. DigitalOcean planned for post-hackathon production migration.          |
| **SDK**                | Vanilla JavaScript (no framework dependency)       | Lightweight embed for marketplace partners. PostMessage communication with iframe widget.                                                                                                            |
| **Admin Dashboard**    | Next.js, Recharts                                  | Real-time charts for Nomba admin. WebSocket for live job and dispute feeds.                                                                                                                          |

### 8.1. Nomba API Integration Map

|                            |                                                                                                                                                                                                                                                                                                                |
|----------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Nomba API**              | **WorkReceipt Usage**                                                                                                                                                                                                                                                                                          |
| **Virtual Accounts API**   | POST /accounts/virtual — create one dedicated account per job. accountRef = job UUID. expectedAmount = job amount in kobo.                                                                                                                                                                                     |
| **Webhook (Inbound)**      | Receive transfer.successful event. Verify HMAC signature. Update job status to FUNDED. Trigger notifications.                                                                                                                                                                                                  |
| **Payout / Transfers API** | POST /transfers/bank/lookup — resolve merchant account name before every payout. POST /transfers/bank — called on approval or auto-release after lookup confirmation. amount = job amount minus advance minus fee. destination = merchant bank account. GET /transfers/{merchantTxRef} — verify payout status. |
| **Checkout API**           | Used for marketplace SDK widget. Buyer checkout experience within partner platforms.                                                                                                                                                                                                                           |
| **Webhook (Outbound)**     | WorkReceipt relays resolution events to marketplace partners via our own webhook relay module.                                                                                                                                                                                                                 |
| **Tokenized Card Flows**   | Phase 2: Buyers can tokenize card for instant escrow funding without bank transfer friction.                                                                                                                                                                                                                   |

## 9. Monetization Model

### 9.1. Revenue Streams

|                               |                              |                                                                                                           |
|-------------------------------|------------------------------|-----------------------------------------------------------------------------------------------------------|
| **Stream**                    | **Rate**                     | **Mechanics**                                                                                             |
| **Transaction Fee**           | **1.2% of job value**        | Deducted from escrow on successful payout. Merchant pays. Invisible on small jobs. Significant at volume. |
| **Advance on Escrow Fee**     | **3.5% flat on advance**     | Charged on drawdown. Highest margin product. Merchant pays for immediate cashflow.                        |
| **Marketplace SDK Licensing** | **₦50k–₦200k/month**         | Tiered by transaction volume. Enterprise partners on revenue share (0.3% of partner-processed volume).    |
| **WorkScore Credit Referral** | **1–2% origination fee**     | WorkReceipt refers verified merchants to Nomba or lending partners. Earns on each loan originated.        |
| **Premium Merchant Profile**  | **₦5,000/month**             | Verified badge, priority dispute resolution, boosted WorkScore visibility in partner marketplace search.  |
| **Dispute Resolution Fee**    | **₦1,500 per filed dispute** | Charged to losing party only. Deters frivolous disputes. Covers human review cost.                        |

### 9.2. Unit Economics (Per Job)

|                                |                                                        |
|--------------------------------|--------------------------------------------------------|
| **Metric**                     | **Value**                                              |
| Average job value              | **₦25,000**                                            |
| Transaction fee (1.2%)         | **₦300**                                               |
| Advance uptake rate (est. 35%) | **₦306 avg per job (35% × 3.5% × ₦25k × 40% advance)** |
| Revenue per job                | **~₦606**                                              |
| Cost per job (infra + SMS)     | **~₦45**                                               |
| Gross margin per job           | **~₦561 (~93%)**                                       |

## 10. Network Effects & Defensibility

WorkReceipt is designed to generate compounding network effects across four dimensions. Each dimension strengthens the others over time.

### 10.1. The Four Network Effects

**Merchant Reputation Loop**

Higher WorkScore generates more job requests from buyers who search within the platform. Every merchant has a structural incentive to complete jobs cleanly and remain on the platform. Reputation compounds — a mechanic with 200 verified jobs is more attractive than a new entrant, permanently.

**Buyer Stickiness Loop**

Buyers who fund escrow once never want to pay without it. The WorkReceipt link becomes the new 'send me your account number.' Buyers start requesting it from merchants who are not yet on the platform, driving organic merchant acquisition at zero cost.

**Data Flywheel**

Every verified job makes WorkScore more accurate. Accuracy improves credit underwriting. Better credit attracts more merchants. More merchants generate more jobs. More jobs generate more data. The model feeds itself — and the data is the moat Nomba cannot replicate without WorkReceipt's history.

**Marketplace Category Density**

Once enough mechanics, tailors, or cleaners in a single city use WorkReceipt, buyers search within the platform for verified providers in that category. It stops being a payment tool and becomes a trust-verified directory. Nomba owns that discovery layer without building a marketplace.

### 10.2. Marketplace Partner Network Effect

Each partner platform that embeds the SDK brings their existing user base into the WorkScore ecosystem. A merchant verified on Jiji, Workstream, and WorkReceipt directly has three times the data points feeding their score. Partners benefit from WorkReceipt's trust infrastructure. WorkReceipt benefits from partner distribution. Classic two-sided flywheel.

### 10.3. The Defensible Moat

|                                                                                                                                                                        |
|------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ***Nomba can copy the escrow feature in 6 weeks. They cannot copy 18 months of verified job history per merchant. The data is the product. The history is the moat.*** |

## 11. Go-to-Market Strategy

### 11.1. Phase 1 — Seeded Launch (Months 1–3)

Target: 500 verified merchants across 3 service categories in Lagos.

- Category focus: mechanics (Ladipo market cluster), tailors (Eko market), freelance tech (Twitter/X community)

- Channel: WhatsApp broadcast lists via existing trade associations. One leader per category as early adopter.

- Incentive: First 100 merchants get zero transaction fee for 3 months. WorkScore badge displayed prominently.

- Onboarding: Field agents in target markets. USSD fallback means zero smartphone barrier.

- Target KPIs: 500 merchants, 1,000 jobs, 0 successful disputes (proof of concept for Nomba).

### 11.2. Phase 2 — Partner Distribution (Months 4–8)

Target: 3 marketplace partner integrations, 5,000 merchants.

- Approach Jiji Nigeria, Workstream.ng, and one trade cooperative with SDK integration offer.

- SDK reduces their dispute support burden immediately — measurable value from Day 1.

- Revenue share model makes partner integration a revenue line for them, not a cost.

- Nomba co-marketing: feature WorkReceipt in Nomba's developer newsletter and partner showcases.

### 11.3. Phase 3 — Credit Product Launch (Months 9–18)

Target: 25,000 merchants, ₦500M in verified job volume, first credit product.

- WorkScore credit API opened to lending partners (LAPO, Carbon, FairMoney, Nomba directly).

- Advance-on-escrow product scaled. Marketed as 'materials financing for service businesses.'

- Expand to 3 additional cities: Abuja, Port Harcourt, Kano.

- PR story: 'The credit score for Nigeria's informal economy.'

### 11.4. Acquisition Channels Summary

|                                      |                       |                                              |
|--------------------------------------|-----------------------|----------------------------------------------|
| **Channel**                          | **Cost**              | **Expected CAC**                             |
| **Field agents + WhatsApp**          | Low                   | ₦800–₦1,200 per merchant                     |
| **Trade association partnerships**   | Zero cash / rev share | ₦300–₦600 per merchant (bulk)                |
| **Marketplace SDK (buyer-driven)**   | Zero (organic)        | ₦0 — buyer requests merchant use WorkReceipt |
| **Nomba co-marketing**               | Zero cash             | Subsidized by hackathon relationship         |
| **Social media (LinkedIn, Twitter)** | Moderate              | ₦1,500–₦2,500 per merchant                   |

## 12. Product Roadmap

|                           |                |                                                                                                                                                                                               |
|---------------------------|----------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Phase**                 | **Timeline**   | **Deliverables**                                                                                                                                                                              |
| **MVP (Hackathon)**       | July 1–7, 2026 | Job creation, Nomba escrow, in-app camera proof, 72hr auto-release, dispute escalation, WorkScore profile, materials advance, marketplace SDK stub, USSD basic flow                           |
| **V1.0 (Post-Hackathon)** | Aug–Sep 2026   | Full USSD integration with Africa's Talking, buyer dispute reputation scoring, production-hardened webhook relay, partner portal, Nomba admin dashboard, SMS dunning for review window expiry |
| **V1.5 (Partner Scale)**  | Oct–Dec 2026   | 3 marketplace partner integrations live, WorkScore public API, SDK documentation site, advance-on-escrow at scale, multi-city onboarding kits                                                 |
| **V2.0 (Credit Layer)**   | Q1–Q2 2027     | WorkScore credit API for lending partners, BNPL for buyers via WorkScore, tokenized card escrow funding, WhatsApp bot for job creation and status, iOS app                                    |
| **V3.0 (Pan-Africa)**     | Q3 2027+       | Ghana and Kenya expansion, multi-currency virtual account escrow, B2B service contracts (SME-to-SME), WorkScore export for formal credit applications                                         |

## 13. Risks & Mitigation

|        |                                                   |                      |                                                                                                                                                                                                           |
|--------|---------------------------------------------------|----------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **\#** | **Risk**                                          | **Severity**         | **Mitigation**                                                                                                                                                                                            |
| R1     | **Nomba API instability / NIBSS downtime**        | **High**             | Idempotent webhook processing. Go goroutine-based event queue with exponential backoff retry, persisted in MySQL. Escrow timer paused during confirmed downtime. Dual NIBSS/UPSL routing per CBN mandate. |
| R2     | **Merchant adoption resistance (prefer cash)**    | **High**             | USSD fallback removes smartphone barrier. Field agents in target markets. Early adopter zero-fee incentive. Trust is the sell — not tech.                                                                 |
| R3     | **Collusive fraud (merchant + buyer fake jobs)**  | **Medium**           | WorkScore anomaly detection: jobs between same merchant/buyer pairs flagged. Advance limits for new merchants. Manual review threshold for high-value jobs.                                               |
| R4     | **Regulatory grey area for escrow holding**       | **Medium**           | Funds held in Nomba virtual accounts — not in WorkReceipt's custody. Nomba holds the CBN license. WorkReceipt is an instruction layer, not a payment institution.                                         |
| R5     | **Dispute volume overwhelming human review**      | **Medium**           | Structured evidence packet reduces review time to under 10 minutes per case. Dispute fee deters frivolous filing. Auto-escalation rules reduce queue depth.                                               |
| R6     | **Proof artifacts gamed (staged photos)**         | **Low–Medium**       | In-app camera only — no gallery. GPS + timestamp injected server-side on upload receipt. Metadata hash mismatch flags manipulation. Dispute score penalizes proven gaming.                                |
| R7     | **Copycat build by Nomba or Paystack**            | **Low (short-term)** | 18 months of verified job history is the moat, not the product. First mover in WorkScore data is defensible. Nomba Developer Partner agreement creates commercial alignment.                              |
| R8     | **Low smartphone penetration in target segments** | **Low**              | USSD channel covers feature phone users fully. Core flow (mark complete, confirm, dispute) works entirely via SMS/USSD.                                                                                   |

## 14. Financial Projections

Projections based on conservative merchant growth and average job value of ₦25,000. Exchange rate assumed at ₦1,600/USD for Year 1.

### 14.1. Three-Year Revenue Model

|                                    |            |            |                |
|------------------------------------|------------|------------|----------------|
| **Metric**                         | **Year 1** | **Year 2** | **Year 3**     |
| **Active Merchants**               | 2,500      | 12,000     | **45,000**     |
| **Jobs per Merchant per Month**    | 4          | 5          | **6**          |
| **Total Monthly Jobs**             | 10,000     | 60,000     | **270,000**    |
| **Avg Job Value (₦)**              | ₦25,000    | ₦28,000    | **₦32,000**    |
| **Monthly GMV (₦)**                | ₦250M      | ₦1.68B     | **₦8.64B**     |
| **Transaction Fee Revenue (1.2%)** | ₦3M/mo     | ₦20.2M/mo  | **₦103.7M/mo** |
| **Advance Fee Revenue (est.)**     | ₦1.1M/mo   | ₦7.4M/mo   | **₦38M/mo**    |
| **SDK Licensing Revenue**          | ₦150k/mo   | ₦2.5M/mo   | **₦12M/mo**    |
| **Total Monthly Revenue**          | ~₦4.25M    | ~₦30.1M    | **~₦153.7M**   |
| **Annual Revenue (₦)**             | ~₦51M      | ~₦361M     | **~₦1.84B**    |
| **Annual Revenue (USD, est.)**     | ~\$31,875  | ~\$225,625 | **~\$1.15M**   |
| **Gross Margin (est. 88%)**        | ₦44.9M     | ₦317.7M    | **₦1.62B**     |

### 14.2. Cost Structure (Year 1 Monthly)

|                                                       |                      |
|-------------------------------------------------------|----------------------|
| **Cost Item**                                         | **Monthly Estimate** |
| DigitalOcean infrastructure (3 droplets + managed DB) | ₦320,000             |
| SMS / USSD (Termii + Africa's Talking)                | ₦180,000             |
| GCS storage (proof artifacts)                         | ₦80,000              |
| Customer support (1 agent)                            | ₦180,000             |
| Field agent costs (Lagos)                             | ₦400,000             |
| Total Monthly OpEx                                    | **~₦1,160,000**      |

### 14.3. Break-Even Analysis

**Monthly OpEx:** ₦1,160,000

**Revenue per job:** ~₦606

**Jobs needed for break-even:** ~1,914 jobs/month

**Merchants needed (at 4 jobs/month):** ~479 active merchants

**Break-even timeline:** Month 3–4 at projected merchant growth rate

## 15. Competitive Landscape

|                       |              |                 |               |                  |
|-----------------------|--------------|-----------------|---------------|------------------|
| **Product**           | **Escrow**   | **Proof Layer** | **WorkScore** | **USSD Channel** |
| **WorkReceipt**       | ✓ Native     | ✓ Multi-type    | ✓ Full        | ✓ Yes            |
| Paystack              | ✗ None       | ✗ None          | ✗ None        | ✗ No             |
| Flutterwave           | ✗ None       | ✗ None          | ✗ None        | ✗ No             |
| Nomba (current)       | ✗ None       | ✗ None          | ✗ None        | Limited          |
| Cowrywise / PiggyVest | Savings only | ✗ None          | ✗ None        | ✗ No             |
| Fiverr Nigeria        | ✓ Escrow     | ✗ None          | Rating only   | ✗ No             |
| Jiji                  | ✗ None       | ✗ None          | ✗ None        | ✗ No             |

|                                                                                                                                                                                 |
|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ***WorkReceipt is the only product in Nigeria that combines escrow, multi-type proof of work, a merchant credit score, and USSD accessibility in a single integrated system.*** |

## 16. MVP Build Plan — Hackathon Window (July 1–7, 2026)

Seven days. Two developers equivalent (solo full-stack). Scope is ruthlessly prioritized to produce a working demo that judges can interact with live on Demo Day.

### 16.1. What We Build vs. What We Stub

|                                     |            |                                                                            |
|-------------------------------------|------------|----------------------------------------------------------------------------|
| **Feature**                         | **Status** | **Notes**                                                                  |
| Job creation + spec locking         | **BUILD**  | Full flow. Hash computed and stored.                                       |
| Nomba virtual account per job       | **BUILD**  | Live Nomba sandbox integration.                                            |
| Webhook listener for escrow funding | **BUILD**  | HMAC verification. Status update on receipt.                               |
| In-app camera with GPS + timestamp  | **BUILD**  | Flutter Camera plugin. Metadata injected server-side on upload.            |
| 72-hour auto-release timer          | **BUILD**  | Go goroutine, idempotent via unique merchantTxRef constraint in MySQL (no Redis).                                  |
| Nomba payout API on resolution      | **BUILD**  | Live call to Nomba sandbox payout endpoint.                                |
| WorkScore profile page              | **BUILD**  | Public page. Static score calculation. Shareable link.                     |
| Dispute escalation UI               | **BUILD**  | Filing flow + evidence packet assembly. Resolution mocked.                 |
| Materials advance drawdown          | **BUILD**  | Partial payout logic. Remaining balance display.                           |
| Nomba admin dashboard               | **BUILD**  | Key metrics. Static data seeded for demo.                                  |
| USSD integration                    | **STUB**   | Menu UI mocked in demo. Reference Africa's Talking integration as Phase 1. |
| Marketplace SDK                     | **STUB**   | Code shown. Integration flow described. Partner portal mocked.             |
| WorkScore → credit API              | **STUB**   | Mention as Phase 2. WorkScore data structure is ready.                     |
| iOS app                             | **SKIP**   | Android / web only for MVP.                                                |

### 16.2. Day-by-Day Build Schedule

|           |                                                                                                                                                                                                                 |
|-----------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Day**   | **Focus**                                                                                                                                                                                                       |
| **Day 1** | Project scaffold. MySQL schema deployed on Hostinger (remote access enabled), backend deployed on Render. Nomba sandbox keys configured. Webhook URL registered with Nomba. Auth module (email OTP via Brevo). Basic job creation API.                       |
| **Day 2** | Nomba virtual account integration. Webhook listener with HMAC verification. Escrow funded state. Proof upload API with metadata hashing.                                                                        |
| **Day 3** | Flutter app: job creation flow, in-app camera, proof submission, job status screen. Flutter Camera plugin GPS integration.                                                                                      |
| **Day 4** | Auto-release timer (Go goroutine + MySQL-persisted job state). Nomba payout API call with /transfers/bank/lookup pre-check. Dispute filing flow. Evidence packet assembly.                                      |
| **Day 5** | WorkScore engine. Public profile page. Materials advance drawdown. Web dashboard for merchants and buyers.                                                                                                      |
| **Day 6** | Nomba admin dashboard. Nightly reconciliation cron job (Go) — compares /transactions against MySQL jobs table, flags orphans and amount drift. End-to-end QA. Seed demo data. USSD mockup for pitch. Polish UI. |
| **Day 7** | Buffer / bug fixes. Submission prep. Demo script rehearsal. Video walkthrough recorded.                                                                                                                         |

## 17. Demo Day Pitch Structure

5-minute pitch. 3 acts. One number to open. One live demo. One strategic close.

**Act 1 — The Problem (90 seconds)**

- Open with one number: 'Nigerian subscription businesses lose 40–50% of revenue to payment failures. But that's the easy problem. The harder one: 90% of Nigeria's GDP is in services that leave no digital trace at all.'

- Hassan the mechanic. ₦40,000 job. No proof. Chargeback. Nomba support team gets two WhatsApp screenshots.

- 'This happens 40% of the time a POS chargeback is filed for services. No one has solved it. Here's why: every solution ever built assumes you can retry a card. Nigeria runs on bank transfers.'

**Act 2 — The Demo (2 minutes)**

- Live: Create a job. Lock the spec. Show virtual account generated via Nomba API.

- Live: Fund the escrow (pre-funded in sandbox). Webhook fires. Both parties notified.

- Live: Submit proof — take in-app photo. GPS + timestamp embedded. Hash displayed.

- Live: Auto-release timer running. Show payout call to Nomba API on confirm.

- Show: WorkScore profile updating. Verified earnings, dispute rate, job history.

- Show: Nomba admin dashboard — dispute rate drop, verified merchant volume.

**Act 3 — The Strategic Close (90 seconds)**

- 'Every job on WorkReceipt is a data point Nomba cannot get any other way. Verified service revenue. Real credit history for 90% of Nigeria's economy that banks have never been able to underwrite.'

- 'We're not asking Nomba to build this. We built it on your APIs. We're asking to go to market together — WorkReceipt as the proof and escrow rail, Nomba as the payment and credit rail.'

- Close: 'Nomba moves money. WorkReceipt makes sure it only moves when work is real — and turns every job into a credit history.'

## 18. Team

**Reed (Ifeanyi Felix) — Founder, Reed Breed Technologies**

**Role:** Full-Stack Engineer, Product Builder, UI/UX Lead

**Stack:** TypeScript/JavaScript, Go, Python, Next.js, React, Flutter, Fastify, Gin/Fiber, MySQL, DigitalOcean, Docker, Anthropic API

**Background:** B.Tech Biotechnology (FUTO 2016), Google UX Design Professional, UI/UX Design Training Lead — Nigeria 3MTT Programme

**Relevant builds:** CISE (AI client intelligence engine), ResultsPRO suite, NexaNG (84-screen business discovery platform), AgroDeal, CareBridge, SignBridge

**Hackathon advantage:** Solo full-stack capacity across product design, backend, frontend, DevOps, and payments. Has shipped production Nomba/Stripe integrations previously.

|                                                                                                                                                                                |
|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ***Reed Breed Technologies is an AI automation and growth systems agency targeting SMEs in Nigeria and Africa. WorkReceipt is the flagship payments infrastructure product.*** |

## 19. Appendix

### 19.1. Key Nomba API Endpoints Referenced

- POST /accounts/virtual — Create virtual account per job

- GET /accounts/virtual/{accountRef} — Check funding status

- POST /webhooks — Register webhook URL for transfer events

- POST /transfers/bank/lookup — Resolve merchant account name before every payout

- POST /checkout/initiate — Marketplace SDK buyer checkout

### 19.2. Webhook Event Reference

- transfer.successful — Escrow funded. Triggers job status: FUNDED.

- transfer.failed — Funding failed. Buyer notified to retry.

- payout.completed — Merchant payout confirmed. WorkScore updated.

- payout.failed — Retry logic triggered. Admin alerted if 3 retries fail.

### 19.3. WorkScore Computation Formula (V1)

WorkScore = (Completed Jobs × 10) + (Verified Earnings Tier × 15) − (Disputes Lost × 25) + (Recency Bonus: +5 if job in last 7 days) − (Inactivity Penalty: −2 per 30-day inactive period)

Score range: 0–1000. Published tiers: Bronze (0–299), Silver (300–599), Gold (600–849), Platinum (850–1000).

### 19.4. Glossary

- Escrow: Funds held by a neutral party (Nomba virtual account) pending job completion.

- WorkScore: Verified merchant reputation score derived from completed job history on WorkReceipt.

- Auto-release: Automatic payout triggered when buyer review window expires without a dispute.

- Proof artifact: Timestamped, GPS-tagged, hashed evidence of job completion.

- Advance on escrow: Partial drawdown of locked funds by merchant before job completion, for materials financing.

- Dispute reputation: Buyer-side score tracking history of disputes filed and outcomes. Deters abuse.

- Spec lock: Immutable hash of job agreement created at job creation and signed by both parties.

**End of Document.**

*Nomba WorkReceipt — Reed Breed Technologies — Lagos, Nigeria — June 2026*
