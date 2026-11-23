-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateEnum
CREATE TYPE "PaymentMethod" AS ENUM ('COD', 'UPI');

-- CreateEnum
CREATE TYPE "PaymentStatus" AS ENUM ('PENDING', 'SUBMITTED', 'PAID', 'VOID');

-- CreateTable
CREATE TABLE "payments" (
    "id" UUID NOT NULL,
    "shop_id" UUID NOT NULL,
    "order_id" UUID NOT NULL,
    "order_number" INTEGER NOT NULL,
    "customer_id" UUID NOT NULL,
    "method" "PaymentMethod" NOT NULL,
    "status" "PaymentStatus" NOT NULL DEFAULT 'PENDING',
    "amount_paise" INTEGER NOT NULL,
    "utr" TEXT,
    "utr_at" TIMESTAMPTZ(3),
    "paid_at" TIMESTAMPTZ(3),
    "paid_by" UUID,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "payments_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "payments_shop_id_status_created_at_idx" ON "payments"("shop_id", "status", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "payments_shop_id_order_id_key" ON "payments"("shop_id", "order_id");


ALTER TABLE "payments" ADD CONSTRAINT "payments_amount_positive" CHECK ("amount_paise" > 0);
