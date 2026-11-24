-- AlterEnum
ALTER TYPE "PaymentMethod" ADD VALUE 'RAZORPAY';

-- AlterTable
ALTER TABLE "payments" ADD COLUMN     "provider_order_id" TEXT,
ADD COLUMN     "provider_payment_id" TEXT;

-- CreateIndex
CREATE UNIQUE INDEX "payments_shop_id_provider_order_id_key" ON "payments"("shop_id", "provider_order_id");

