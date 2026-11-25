-- CreateTable
CREATE TABLE "admin_devices" (
    "id" UUID NOT NULL,
    "session_id" UUID NOT NULL,
    "email" TEXT NOT NULL,
    "token" TEXT NOT NULL,
    "platform" TEXT NOT NULL,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "admin_devices_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "admin_devices_token_key" ON "admin_devices"("token");

-- AddForeignKey
ALTER TABLE "admin_devices" ADD CONSTRAINT "admin_devices_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "admin_sessions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

