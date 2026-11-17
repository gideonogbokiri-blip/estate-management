CREATE TYPE "EstateAnnouncementStatus" AS ENUM ('DRAFT', 'PUBLISHED');
CREATE TYPE "EstateAnnouncementPriority" AS ENUM ('NORMAL', 'EMERGENCY');

CREATE TABLE "estate_announcements" (
    "id" UUID NOT NULL,
    "estate_id" UUID NOT NULL,
    "title" VARCHAR(160) NOT NULL,
    "body" VARCHAR(5000) NOT NULL,
    "priority" "EstateAnnouncementPriority" NOT NULL DEFAULT 'NORMAL',
    "audience" VARCHAR(40) NOT NULL DEFAULT 'ALL_RESIDENTS',
    "status" "EstateAnnouncementStatus" NOT NULL DEFAULT 'DRAFT',
    "created_by_id" UUID NOT NULL,
    "published_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    CONSTRAINT "estate_announcements_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "estate_announcements_estate_id_fkey" FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "estate_announcements_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE INDEX "estate_announcements_estate_id_status_published_at_idx" ON "estate_announcements"("estate_id", "status", "published_at");

CREATE TABLE "estate_announcement_reads" (
    "id" UUID NOT NULL,
    "announcement_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "read_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "estate_announcement_reads_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "estate_announcement_reads_announcement_id_fkey" FOREIGN KEY ("announcement_id") REFERENCES "estate_announcements"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "estate_announcement_reads_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "estate_announcement_reads_announcement_id_user_id_key" ON "estate_announcement_reads"("announcement_id", "user_id");
CREATE INDEX "estate_announcement_reads_user_id_read_at_idx" ON "estate_announcement_reads"("user_id", "read_at");
