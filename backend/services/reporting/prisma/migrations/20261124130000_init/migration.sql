-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateTable
CREATE TABLE "sale_orders" (
    "order_id" UUID NOT NULL,
    "shop_id" UUID NOT NULL,
    "number" INTEGER NOT NULL,
    "customer_id" UUID NOT NULL,
    "placed_at" TIMESTAMPTZ(3) NOT NULL,
    "placed_day" DATE NOT NULL,
    "fulfillment" TEXT NOT NULL,
    "payment_method" TEXT NOT NULL,
    "total_paise" INTEGER NOT NULL,
    "item_count" INTEGER NOT NULL,
    "is_list_order" BOOLEAN NOT NULL DEFAULT false,
    "status" TEXT NOT NULL,
    "completed_at" TIMESTAMPTZ(3),

    CONSTRAINT "sale_orders_pkey" PRIMARY KEY ("shop_id","order_id")
);

-- CreateTable
CREATE TABLE "sale_items" (
    "shop_id" UUID NOT NULL,
    "order_id" UUID NOT NULL,
    "variant_id" UUID NOT NULL,
    "product_id" UUID NOT NULL,
    "product_name" TEXT NOT NULL,
    "variant_label" TEXT NOT NULL,
    "qty" INTEGER NOT NULL,
    "line_total_paise" INTEGER NOT NULL,
    "placed_day" DATE NOT NULL,

    CONSTRAINT "sale_items_pkey" PRIMARY KEY ("shop_id","order_id","variant_id")
);

-- CreateTable
CREATE TABLE "sale_payments" (
    "shop_id" UUID NOT NULL,
    "order_id" UUID NOT NULL,
    "paid_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "sale_payments_pkey" PRIMARY KEY ("shop_id","order_id")
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
CREATE INDEX "sale_orders_shop_id_placed_day_idx" ON "sale_orders"("shop_id", "placed_day");

-- CreateIndex
CREATE INDEX "sale_orders_shop_id_customer_id_placed_at_idx" ON "sale_orders"("shop_id", "customer_id", "placed_at");

-- CreateIndex
CREATE INDEX "sale_items_shop_id_placed_day_idx" ON "sale_items"("shop_id", "placed_day");

-- AddForeignKey
ALTER TABLE "sale_items" ADD CONSTRAINT "sale_items_shop_id_order_id_fkey" FOREIGN KEY ("shop_id", "order_id") REFERENCES "sale_orders"("shop_id", "order_id") ON DELETE CASCADE ON UPDATE RESTRICT;

