-- CreateEnum
CREATE TYPE "MediaKind" AS ENUM ('PRODUCT_IMAGE', 'CATEGORY_IMAGE');

-- CreateEnum
CREATE TYPE "Visibility" AS ENUM ('PUBLIC', 'PRIVATE');

-- CreateTable
CREATE TABLE "media_files" (
    "id" UUID NOT NULL,
    "shop_id" UUID NOT NULL,
    "uploaded_by" UUID NOT NULL,
    "kind" "MediaKind" NOT NULL,
    "visibility" "Visibility" NOT NULL,
    "path" TEXT NOT NULL,
    "thumb_path" TEXT NOT NULL,
    "width" INTEGER NOT NULL,
    "height" INTEGER NOT NULL,
    "bytes" INTEGER NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deleted_at" TIMESTAMPTZ(3),

    CONSTRAINT "media_files_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "media_files_shop_id_kind_created_at_idx" ON "media_files"("shop_id", "kind", "created_at");
