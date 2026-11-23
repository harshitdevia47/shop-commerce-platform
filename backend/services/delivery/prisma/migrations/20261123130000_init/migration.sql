-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateEnum
CREATE TYPE "DeliveryStatus" AS ENUM ('ASSIGNED', 'PICKED_UP', 'DELIVERED', 'CANCELLED');

-- CreateTable
CREATE TABLE "deliveries" (
    "id" UUID NOT NULL,
    "shop_id" UUID NOT NULL,
    "order_id" UUID NOT NULL,
    "order_number" INTEGER NOT NULL,
    "customer_id" UUID NOT NULL,
    "customer_name" TEXT,
    "customer_phone" TEXT NOT NULL,
    "address" JSONB NOT NULL,
    "note" TEXT,
    "item_count" INTEGER NOT NULL,
    "total_paise" INTEGER NOT NULL,
    "cod_paise" INTEGER NOT NULL,
    "rider_id" UUID NOT NULL,
    "rider_name" TEXT,
    "rider_phone" TEXT NOT NULL,
    "status" "DeliveryStatus" NOT NULL DEFAULT 'ASSIGNED',
    "otp" TEXT NOT NULL,
    "otp_attempts" INTEGER NOT NULL DEFAULT 0,
    "assigned_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "picked_up_at" TIMESTAMPTZ(3),
    "delivered_at" TIMESTAMPTZ(3),
    "cancelled_at" TIMESTAMPTZ(3),
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "deliveries_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "outbox_events" (
    "id" UUID NOT NULL,
    "shop_id" UUID NOT NULL,
    "type" TEXT NOT NULL,
    "stream" TEXT NOT NULL,
    "envelope" JSONB NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "outbox_events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "processed_events" (
    "shop_id" UUID NOT NULL,
    "event_id" UUID NOT NULL,
    "type" TEXT NOT NULL,
    "processed_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "processed_events_pkey" PRIMARY KEY ("shop_id","event_id")
);

-- CreateIndex
CREATE INDEX "deliveries_shop_id_rider_id_status_idx" ON "deliveries"("shop_id", "rider_id", "status");

-- CreateIndex
CREATE UNIQUE INDEX "deliveries_shop_id_order_id_key" ON "deliveries"("shop_id", "order_id");

