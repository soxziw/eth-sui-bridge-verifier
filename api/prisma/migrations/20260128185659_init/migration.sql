/*
  Warnings:

  - Added the required column `conditionTxId` to the `MPTProof` table without a default value. This is not possible if the table is not empty.

*/
-- RedefineTables
PRAGMA defer_foreign_keys=ON;
PRAGMA foreign_keys=OFF;
CREATE TABLE "new_MPTProof" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "objectId" TEXT NOT NULL,
    "conditionTxId" TEXT NOT NULL,
    "blockNumber" TEXT NOT NULL,
    "account" TEXT NOT NULL,
    "balance" TEXT NOT NULL
);
INSERT INTO "new_MPTProof" ("account", "balance", "blockNumber", "id", "objectId") SELECT "account", "balance", "blockNumber", "id", "objectId" FROM "MPTProof";
DROP TABLE "MPTProof";
ALTER TABLE "new_MPTProof" RENAME TO "MPTProof";
CREATE UNIQUE INDEX "MPTProof_objectId_key" ON "MPTProof"("objectId");
CREATE INDEX "MPTProof_conditionTxId_idx" ON "MPTProof"("conditionTxId");
CREATE INDEX "MPTProof_blockNumber_idx" ON "MPTProof"("blockNumber");
CREATE INDEX "MPTProof_account_idx" ON "MPTProof"("account");
PRAGMA foreign_keys=ON;
PRAGMA defer_foreign_keys=OFF;
