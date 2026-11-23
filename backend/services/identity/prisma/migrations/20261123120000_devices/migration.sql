-- CreateTable
CREATE TABLE "devices" (
    "id" UUID NOT NULL,
    "shop_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "token" TEXT NOT NULL,
    "platform" TEXT NOT NULL,
    "locale" TEXT NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "devices_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "devices_shop_id_user_id_idx" ON "devices"("shop_id", "user_id");

-- CreateIndex
CREATE UNIQUE INDEX "devices_shop_id_token_key" ON "devices"("shop_id", "token");

-- AddForeignKey
ALTER TABLE "devices" ADD CONSTRAINT "devices_shop_id_user_id_fkey" FOREIGN KEY ("shop_id", "user_id") REFERENCES "users"("shop_id", "id") ON DELETE CASCADE ON UPDATE RESTRICT;

