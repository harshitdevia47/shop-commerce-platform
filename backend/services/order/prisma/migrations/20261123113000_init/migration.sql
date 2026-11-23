-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateEnum
CREATE TYPE "OrderStatus" AS ENUM ('PLACED', 'CONFIRMED', 'PACKED', 'OUT_FOR_DELIVERY', 'READY_FOR_PICKUP', 'DELIVERED', 'PICKED_UP', 'CANCELLED', 'REJECTED');

-- CreateEnum
CREATE TYPE "Fulfillment" AS ENUM ('DELIVERY', 'PICKUP');

-- CreateEnum
CREATE TYPE "PaymentMethod" AS ENUM ('COD', 'UPI');

-- CreateTable
CREATE TABLE "orders" (
    "id" UUID NOT NULL,
    "shop_id" UUID NOT NULL,
    "number" INTEGER NOT NULL,
    "customer_id" UUID NOT NULL,
    "customer_phone" TEXT NOT NULL,
    "customer_name" TEXT,
    "status" "OrderStatus" NOT NULL DEFAULT 'PLACED',
    "fulfillment" "Fulfillment" NOT NULL,
    "address" JSONB,
    "note" TEXT,
    "payment_method" "PaymentMethod" NOT NULL,
    "subtotal_paise" INTEGER NOT NULL,
    "delivery_fee_paise" INTEGER NOT NULL,
    "total_paise" INTEGER NOT NULL,
    "item_count" INTEGER NOT NULL,
    "idempotency_key" UUID NOT NULL,
    "cancel_reason" TEXT,
    "placed_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "orders_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "order_items" (
    "id" UUID NOT NULL,
    "shop_id" UUID NOT NULL,
    "order_id" UUID NOT NULL,
    "product_id" UUID NOT NULL,
    "variant_id" UUID NOT NULL,
    "product_name" TEXT NOT NULL,
    "product_name_i18n" JSONB,
    "variant_label" TEXT NOT NULL,
    "variant_label_i18n" JSONB,
    "thumb_url" TEXT,
    "price_paise" INTEGER NOT NULL,
    "mrp_paise" INTEGER,
    "qty" INTEGER NOT NULL,
    "line_total_paise" INTEGER NOT NULL,

    CONSTRAINT "order_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "order_status_changes" (
    "id" UUID NOT NULL,
    "shop_id" UUID NOT NULL,
    "order_id" UUID NOT NULL,
    "from" "OrderStatus",
    "to" "OrderStatus" NOT NULL,
    "by_user_id" UUID,
    "by_role" TEXT,
    "reason" TEXT,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "order_status_changes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "order_counters" (
    "shop_id" UUID NOT NULL,
    "last_number" INTEGER NOT NULL,

    CONSTRAINT "order_counters_pkey" PRIMARY KEY ("shop_id")
);

-- CreateIndex
CREATE INDEX "orders_shop_id_status_id_idx" ON "orders"("shop_id", "status", "id");

-- CreateIndex
CREATE INDEX "orders_shop_id_customer_id_id_idx" ON "orders"("shop_id", "customer_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "orders_shop_id_id_key" ON "orders"("shop_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "orders_shop_id_number_key" ON "orders"("shop_id", "number");

-- CreateIndex
CREATE UNIQUE INDEX "orders_shop_id_customer_id_idempotency_key_key" ON "orders"("shop_id", "customer_id", "idempotency_key");

-- CreateIndex
CREATE INDEX "order_items_shop_id_order_id_idx" ON "order_items"("shop_id", "order_id");

-- CreateIndex
CREATE INDEX "order_status_changes_shop_id_order_id_created_at_idx" ON "order_status_changes"("shop_id", "order_id", "created_at");

-- AddForeignKey
ALTER TABLE "order_items" ADD CONSTRAINT "order_items_shop_id_order_id_fkey" FOREIGN KEY ("shop_id", "order_id") REFERENCES "orders"("shop_id", "id") ON DELETE CASCADE ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "order_status_changes" ADD CONSTRAINT "order_status_changes_shop_id_order_id_fkey" FOREIGN KEY ("shop_id", "order_id") REFERENCES "orders"("shop_id", "id") ON DELETE CASCADE ON UPDATE RESTRICT;


-- Money and quantity sanity checks.
ALTER TABLE "orders" ADD CONSTRAINT "orders_amounts_nonnegative" CHECK ("subtotal_paise" >= 0 AND "delivery_fee_paise" >= 0 AND "total_paise" = "subtotal_paise" + "delivery_fee_paise");
ALTER TABLE "order_items" ADD CONSTRAINT "order_items_qty_positive" CHECK ("qty" > 0 AND "line_total_paise" = "price_paise" * "qty");
