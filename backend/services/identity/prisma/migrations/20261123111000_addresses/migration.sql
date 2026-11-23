-- CreateTable
CREATE TABLE "addresses" (
    "id" UUID NOT NULL,
    "shop_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "label" TEXT NOT NULL DEFAULT 'home',
    "name" TEXT,
    "phone" TEXT,
    "line1" TEXT NOT NULL,
    "line2" TEXT,
    "landmark" TEXT,
    "city" TEXT NOT NULL,
    "pincode" CHAR(6) NOT NULL,
    "lat" DOUBLE PRECISION,
    "lng" DOUBLE PRECISION,
    "is_default" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "deleted_at" TIMESTAMPTZ(3),

    CONSTRAINT "addresses_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "addresses_shop_id_user_id_idx" ON "addresses"("shop_id", "user_id");

-- CreateIndex
CREATE UNIQUE INDEX "users_shop_id_id_key" ON "users"("shop_id", "id");

-- AddForeignKey
ALTER TABLE "addresses" ADD CONSTRAINT "addresses_shop_id_user_id_fkey" FOREIGN KEY ("shop_id", "user_id") REFERENCES "users"("shop_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

