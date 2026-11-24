-- CreateEnum
CREATE TYPE "ReturnType" AS ENUM ('RETURN', 'EXCHANGE');

-- CreateEnum
CREATE TYPE "ReturnStatus" AS ENUM ('REQUESTED', 'APPROVED', 'REJECTED', 'COMPLETED');

-- AlterTable
ALTER TABLE "orders" ADD COLUMN     "attachments" JSONB,
ADD COLUMN     "needs_pricing" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "slot_end" TIMESTAMPTZ(3),
ADD COLUMN     "slot_start" TIMESTAMPTZ(3);

-- CreateTable
CREATE TABLE "slot_bookings" (
    "shop_id" UUID NOT NULL,
    "slot_start" TIMESTAMPTZ(3) NOT NULL,
    "booked" INTEGER NOT NULL,

    CONSTRAINT "slot_bookings_pkey" PRIMARY KEY ("shop_id","slot_start")
);

-- CreateTable
CREATE TABLE "return_requests" (
    "id" UUID NOT NULL,
    "shop_id" UUID NOT NULL,
    "order_id" UUID NOT NULL,
    "customer_id" UUID NOT NULL,
    "type" "ReturnType" NOT NULL,
    "status" "ReturnStatus" NOT NULL DEFAULT 'REQUESTED',
    "reason" TEXT NOT NULL,
    "items" JSONB NOT NULL,
    "photos" JSONB,
    "shop_note" TEXT,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "return_requests_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "return_requests_shop_id_status_created_at_idx" ON "return_requests"("shop_id", "status", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "return_requests_shop_id_order_id_key" ON "return_requests"("shop_id", "order_id");

-- CreateIndex
CREATE INDEX "orders_shop_id_slot_start_idx" ON "orders"("shop_id", "slot_start");

-- AddForeignKey
ALTER TABLE "return_requests" ADD CONSTRAINT "return_requests_shop_id_order_id_fkey" FOREIGN KEY ("shop_id", "order_id") REFERENCES "orders"("shop_id", "id") ON DELETE CASCADE ON UPDATE RESTRICT;

