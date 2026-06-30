package main

import (
	"context"
	"log"
	"time"

	"github.com/joho/godotenv"
	"github.com/shuddy05/Nomba-Work-Receipt-Backend/prisma/db"
)

func main() {
	// Load environment variables
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found, relying on environment variables")
	}

	client := db.NewClient()
	if err := client.Connect(); err != nil {
		log.Fatalf("failed to connect to database: %v", err)
	}

	defer func() {
		if err := client.Disconnect(); err != nil {
			log.Fatalf("failed to disconnect: %v", err)
		}
	}()

	ctx := context.Background()

	log.Println("Clearing database tables...")
	_, _ = client.Prisma.ExecuteRaw("SET FOREIGN_KEY_CHECKS = 0").Exec(ctx)
	_, _ = client.Prisma.ExecuteRaw("TRUNCATE TABLE webhook_events").Exec(ctx)
	_, _ = client.Prisma.ExecuteRaw("TRUNCATE TABLE notifications").Exec(ctx)
	_, _ = client.Prisma.ExecuteRaw("TRUNCATE TABLE workscore_events").Exec(ctx)
	_, _ = client.Prisma.ExecuteRaw("TRUNCATE TABLE disputes").Exec(ctx)
	_, _ = client.Prisma.ExecuteRaw("TRUNCATE TABLE checkins").Exec(ctx)
	_, _ = client.Prisma.ExecuteRaw("TRUNCATE TABLE proof_artifacts").Exec(ctx)
	_, _ = client.Prisma.ExecuteRaw("TRUNCATE TABLE payouts").Exec(ctx)
	_, _ = client.Prisma.ExecuteRaw("TRUNCATE TABLE escrow_accounts").Exec(ctx)
	_, _ = client.Prisma.ExecuteRaw("TRUNCATE TABLE jobs").Exec(ctx)
	_, _ = client.Prisma.ExecuteRaw("TRUNCATE TABLE refresh_tokens").Exec(ctx)
	_, _ = client.Prisma.ExecuteRaw("TRUNCATE TABLE otp_codes").Exec(ctx)
	_, _ = client.Prisma.ExecuteRaw("TRUNCATE TABLE users").Exec(ctx)
	_, _ = client.Prisma.ExecuteRaw("SET FOREIGN_KEY_CHECKS = 1").Exec(ctx)

	log.Println("Seeding users...")

	// 1. Seed Users
	merchant, err := client.User.CreateOne(
		db.User.Role.Set(db.RoleMerchant),
		db.User.ID.Set("merchant-uuid-1"),
		db.User.Phone.Set("+2348011111111"),
		db.User.Email.Set("merchant@example.com"),
		db.User.PasswordHash.Set("hashed_merchant_password"),
		db.User.Name.Set("Kabiru Repairs"),
		db.User.NombaAccountID.Set("nomba-merchant-acc-123"),
		db.User.BankCode.Set("058"),
		db.User.BankAccountNumber.Set("0123456789"),
		db.User.BankAccountName.Set("Kabiru Repairs Ltd"),
		db.User.Workscore.Set(85),
	).Exec(ctx)
	if err != nil {
		log.Fatalf("failed to create merchant user: %v", err)
	}

	buyer, err := client.User.CreateOne(
		db.User.Role.Set(db.RoleBuyer),
		db.User.ID.Set("buyer-uuid-1"),
		db.User.Phone.Set("+2348022222222"),
		db.User.Email.Set("buyer@example.com"),
		db.User.PasswordHash.Set("hashed_buyer_password"),
		db.User.Name.Set("Chinedu Buyer"),
		db.User.NombaAccountID.Set("nomba-buyer-acc-456"),
		db.User.BankCode.Set("011"),
		db.User.BankAccountNumber.Set("9876543210"),
		db.User.BankAccountName.Set("Chinedu Buyer Enterprises"),
		db.User.Workscore.Set(0),
	).Exec(ctx)
	if err != nil {
		log.Fatalf("failed to create buyer user: %v", err)
	}

	_, err = client.User.CreateOne(
		db.User.Role.Set(db.RoleAdmin),
		db.User.ID.Set("admin-uuid-1"),
		db.User.Phone.Set("+2348033333333"),
		db.User.Email.Set("admin@example.com"),
		db.User.PasswordHash.Set("hashed_admin_password"),
		db.User.Name.Set("Nomba Admin"),
		db.User.Workscore.Set(0),
	).Exec(ctx)
	if err != nil {
		log.Fatalf("failed to create admin user: %v", err)
	}

	log.Println("Seeding OTP codes...")
	_, err = client.OtpCode.CreateOne(
		db.OtpCode.Email.Set("merchant@example.com"),
		db.OtpCode.Code.Set("123456"),
		db.OtpCode.ExpiresAt.Set(time.Now().Add(5 * time.Minute)),
		db.OtpCode.ID.Set("otp-uuid-1"),
		db.OtpCode.Used.Set(false),
	).Exec(ctx)
	if err != nil {
		log.Fatalf("failed to create otp code: %v", err)
	}

	log.Println("Seeding jobs and escrow...")
	// 2. Seed Jobs
	job1, err := client.Job.CreateOne(
		db.Job.Title.Set("Generator Engine Overhaul"),
		db.Job.AmountKobo.Set(15000000), // ₦150,000
		db.Job.ProofType.Set(db.ProofTypePhoto),
		db.Job.Merchant.Link(db.User.ID.Equals(merchant.ID)),
		db.Job.ID.Set("job-uuid-1"),
		db.Job.Description.Set("Repair and service Mikano 20KVA generator engine, changing oil filters and ring piston."),
		db.Job.ReviewWindowHours.Set(72),
		db.Job.Status.Set(db.JobStatusFunded),
		db.Job.Buyer.Link(db.User.ID.Equals(buyer.ID)),
	).Exec(ctx)
	if err != nil {
		log.Fatalf("failed to create job: %v", err)
	}

	// 3. Seed Escrow Account for job1
	_, err = client.EscrowAccount.CreateOne(
		db.EscrowAccount.VirtualAccountNumber.Set("9912345678"),
		db.EscrowAccount.BankName.Set("Nomba Sandbox Bank"),
		db.EscrowAccount.AccountName.Set("NombaWR-Kabiru Repairs"),
		db.EscrowAccount.NombaAccountRef.Set("job-uuid-1"),
		db.EscrowAccount.ExpectedAmountKobo.Set(15000000),
		db.EscrowAccount.Job.Link(db.Job.ID.Equals(job1.ID)),
		db.EscrowAccount.ID.Set("escrow-uuid-1"),
		db.EscrowAccount.ReceivedAmountKobo.Set(15000000),
		db.EscrowAccount.Status.Set(db.EscrowStatusFunded),
		db.EscrowAccount.FundedAt.Set(time.Now().Add(-2 * time.Hour)),
	).Exec(ctx)
	if err != nil {
		log.Fatalf("failed to create escrow account: %v", err)
	}

	log.Println("Seeding workscore events...")
	// 4. Seed Workscore Event for merchant
	_, err = client.WorkscoreEvent.CreateOne(
		db.WorkscoreEvent.EventType.Set(db.WorkscoreEventTypeEarningsMilestone),
		db.WorkscoreEvent.ScoreDelta.Set(10),
		db.WorkscoreEvent.RunningScore.Set(85),
		db.WorkscoreEvent.Merchant.Link(db.User.ID.Equals(merchant.ID)),
		db.WorkscoreEvent.ID.Set("workscore-event-uuid-1"),
		db.WorkscoreEvent.Job.Link(db.Job.ID.Equals(job1.ID)),
	).Exec(ctx)
	if err != nil {
		log.Fatalf("failed to create workscore event: %v", err)
	}

	log.Println("Seeding notifications...")
	// 5. Seed Notification
	_, err = client.Notification.CreateOne(
		db.Notification.Type.Set(db.NotificationTypeEscrowFunded),
		db.Notification.Message.Set("Your job 'Generator Engine Overhaul' has been fully funded by the buyer. You can now begin work."),
		db.Notification.User.Link(db.User.ID.Equals(merchant.ID)),
		db.Notification.ID.Set("notification-uuid-1"),
		db.Notification.Job.Link(db.Job.ID.Equals(job1.ID)),
	).Exec(ctx)
	if err != nil {
		log.Fatalf("failed to create notification: %v", err)
	}

	log.Println("Database seeded successfully with test data!")
}
