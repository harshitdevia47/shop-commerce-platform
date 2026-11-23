-- Trigram search on products (index starts with shop_id, via btree_gin).
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS btree_gin;

-- CreateTable
CREATE TABLE "categories" (
    "id" UUID NOT NULL,
    "shop_id" UUID NOT NULL,
    "parent_id" UUID,
    "name" TEXT NOT NULL,
    "name_i18n" JSONB,
    "image_media_id" UUID,
    "image_url" TEXT,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "deleted_at" TIMESTAMPTZ(3),

    CONSTRAINT "categories_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "products" (
    "id" UUID NOT NULL,
    "shop_id" UUID NOT NULL,
    "category_id" UUID,
    "name" TEXT NOT NULL,
    "name_i18n" JSONB,
    "description" TEXT,
    "description_i18n" JSONB,
    "custom_fields" JSONB NOT NULL DEFAULT '{}',
    "tags" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "search_text" TEXT NOT NULL,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "deleted_at" TIMESTAMPTZ(3),

    CONSTRAINT "products_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "variants" (
    "id" UUID NOT NULL,
    "shop_id" UUID NOT NULL,
    "product_id" UUID NOT NULL,
    "label" TEXT NOT NULL,
    "label_i18n" JSONB,
    "options" JSONB NOT NULL DEFAULT '{}',
    "sku" TEXT,
    "price_paise" INTEGER NOT NULL,
    "mrp_paise" INTEGER,
    "stock_qty" INTEGER,
    "is_available" BOOLEAN NOT NULL DEFAULT true,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "deleted_at" TIMESTAMPTZ(3),

    CONSTRAINT "variants_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "product_images" (
    "id" UUID NOT NULL,
    "shop_id" UUID NOT NULL,
    "product_id" UUID NOT NULL,
    "media_id" UUID NOT NULL,
    "url" TEXT NOT NULL,
    "thumb_url" TEXT NOT NULL,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "product_images_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "categories_shop_id_parent_id_sort_order_idx" ON "categories"("shop_id", "parent_id", "sort_order");

-- CreateIndex
CREATE UNIQUE INDEX "categories_shop_id_id_key" ON "categories"("shop_id", "id");

-- CreateIndex
CREATE INDEX "products_shop_id_category_id_sort_order_idx" ON "products"("shop_id", "category_id", "sort_order");

-- CreateIndex
CREATE INDEX "products_shop_id_is_active_sort_order_idx" ON "products"("shop_id", "is_active", "sort_order");

-- CreateIndex
CREATE UNIQUE INDEX "products_shop_id_id_key" ON "products"("shop_id", "id");

-- CreateIndex
CREATE INDEX "variants_shop_id_product_id_sort_order_idx" ON "variants"("shop_id", "product_id", "sort_order");

-- CreateIndex
CREATE UNIQUE INDEX "variants_shop_id_id_key" ON "variants"("shop_id", "id");

-- CreateIndex
CREATE INDEX "product_images_shop_id_product_id_sort_order_idx" ON "product_images"("shop_id", "product_id", "sort_order");

-- AddForeignKey
ALTER TABLE "categories" ADD CONSTRAINT "categories_shop_id_parent_id_fkey" FOREIGN KEY ("shop_id", "parent_id") REFERENCES "categories"("shop_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "products" ADD CONSTRAINT "products_shop_id_category_id_fkey" FOREIGN KEY ("shop_id", "category_id") REFERENCES "categories"("shop_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "variants" ADD CONSTRAINT "variants_shop_id_product_id_fkey" FOREIGN KEY ("shop_id", "product_id") REFERENCES "products"("shop_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "product_images" ADD CONSTRAINT "product_images_shop_id_product_id_fkey" FOREIGN KEY ("shop_id", "product_id") REFERENCES "products"("shop_id", "id") ON DELETE CASCADE ON UPDATE RESTRICT;

-- Search: products of one shop whose search_text contains the query.
CREATE INDEX "products_shop_id_search_text_trgm_idx" ON "products" USING gin ("shop_id", "search_text" gin_trgm_ops);

-- Money and stock sanity checks.
ALTER TABLE "variants" ADD CONSTRAINT "variants_price_nonnegative" CHECK ("price_paise" >= 0);
ALTER TABLE "variants" ADD CONSTRAINT "variants_mrp_gte_price" CHECK ("mrp_paise" IS NULL OR "mrp_paise" >= "price_paise");
ALTER TABLE "variants" ADD CONSTRAINT "variants_stock_nonnegative" CHECK ("stock_qty" IS NULL OR "stock_qty" >= 0);
ALTER TABLE "categories" ADD CONSTRAINT "categories_not_own_parent" CHECK ("parent_id" IS NULL OR "parent_id" <> "id");
