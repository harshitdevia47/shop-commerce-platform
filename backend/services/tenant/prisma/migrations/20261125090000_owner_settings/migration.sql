-- AlterTable
ALTER TABLE "shops" ADD COLUMN     "ordering" JSONB,
ADD COLUMN     "settings_edited_at" TIMESTAMPTZ(3);

