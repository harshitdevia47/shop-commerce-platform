-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateTable
CREATE TABLE "admin_login_codes" (
    "id" UUID NOT NULL,
    "email" TEXT NOT NULL,
    "code_hash" TEXT NOT NULL,
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "expires_at" TIMESTAMPTZ(3) NOT NULL,
    "consumed_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "admin_login_codes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "admin_sessions" (
    "id" UUID NOT NULL,
    "token_hash" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "expires_at" TIMESTAMPTZ(3) NOT NULL,
    "last_seen_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "admin_sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "subscriptions" (
    "shop_id" UUID NOT NULL,
    "slug" TEXT NOT NULL,
    "fee_paise" INTEGER NOT NULL,
    "due_day" INTEGER NOT NULL,
    "next_due_date" DATE NOT NULL,
    "extended_until" DATE,
    "paused_at" TIMESTAMPTZ(3),
    "logo_done" BOOLEAN NOT NULL DEFAULT false,
    "play_done" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "subscriptions_pkey" PRIMARY KEY ("shop_id")
);

-- CreateTable
CREATE TABLE "subscription_payments" (
    "id" UUID NOT NULL,
    "shop_id" UUID NOT NULL,
    "amount_paise" INTEGER NOT NULL,
    "upi_ref" TEXT,
    "paid_on" DATE NOT NULL,
    "months" INTEGER NOT NULL DEFAULT 1,
    "note" TEXT,
    "recorded_by" TEXT NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "subscription_payments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "alert_log" (
    "id" UUID NOT NULL,
    "shop_id" UUID NOT NULL,
    "kind" TEXT NOT NULL,
    "due_date" DATE NOT NULL,
    "sent_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "alert_log_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "used_forms" (
    "id" TEXT NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "used_forms_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "daily_mails" (
    "day" DATE NOT NULL,
    "sent_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "daily_mails_pkey" PRIMARY KEY ("day")
);

-- CreateIndex
CREATE INDEX "admin_login_codes_email_created_at_idx" ON "admin_login_codes"("email", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "admin_sessions_token_hash_key" ON "admin_sessions"("token_hash");

-- CreateIndex
CREATE INDEX "subscription_payments_shop_id_paid_on_idx" ON "subscription_payments"("shop_id", "paid_on");

-- CreateIndex
CREATE UNIQUE INDEX "alert_log_shop_id_kind_due_date_key" ON "alert_log"("shop_id", "kind", "due_date");

-- AddForeignKey
ALTER TABLE "subscription_payments" ADD CONSTRAINT "subscription_payments_shop_id_fkey" FOREIGN KEY ("shop_id") REFERENCES "subscriptions"("shop_id") ON DELETE CASCADE ON UPDATE CASCADE;

