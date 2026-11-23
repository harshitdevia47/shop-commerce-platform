-- AlterTable
ALTER TABLE "stock_reservations" ADD COLUMN     "committed_at" TIMESTAMPTZ(3);

-- CreateTable
CREATE TABLE "processed_events" (
    "shop_id" UUID NOT NULL,
    "event_id" UUID NOT NULL,
    "type" TEXT NOT NULL,
    "processed_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "processed_events_pkey" PRIMARY KEY ("shop_id","event_id")
);

