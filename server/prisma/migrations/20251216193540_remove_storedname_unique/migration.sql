/*
  Warnings:

  - You are about to drop the column `mimeType` on the `File` table. All the data in the column will be lost.

*/
-- DropIndex
DROP INDEX "File_deletedAt_idx";

-- DropIndex
DROP INDEX "File_lastModified_idx";

-- DropIndex
DROP INDEX "File_storedName_key";

-- DropIndex
DROP INDEX "File_userId_idx";

-- AlterTable
ALTER TABLE "File" DROP COLUMN "mimeType";

-- CreateIndex
CREATE INDEX "File_userId_deletedAt_idx" ON "File"("userId", "deletedAt");
