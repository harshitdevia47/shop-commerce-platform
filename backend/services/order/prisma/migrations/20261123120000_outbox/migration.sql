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

