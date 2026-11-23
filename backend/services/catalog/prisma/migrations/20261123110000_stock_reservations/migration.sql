-- CreateTable
CREATE TABLE "stock_reservations" (
    "id" UUID NOT NULL,
    "shop_id" UUID NOT NULL,
    "order_id" UUID NOT NULL,
    "variant_id" UUID NOT NULL,
    "qty" INTEGER NOT NULL,
    "tracked" BOOLEAN NOT NULL,
    "released_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "stock_reservations_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "stock_reservations_qty_positive" CHECK ("qty" > 0)
);

-- CreateIndex
CREATE UNIQUE INDEX "stock_reservations_shop_id_order_id_variant_id_key" ON "stock_reservations"("shop_id", "order_id", "variant_id");

-- AddForeignKey
ALTER TABLE "stock_reservations" ADD CONSTRAINT "stock_reservations_shop_id_variant_id_fkey" FOREIGN KEY ("shop_id", "variant_id") REFERENCES "variants"("shop_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;
