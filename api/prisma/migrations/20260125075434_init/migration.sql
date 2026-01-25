-- CreateTable
CREATE TABLE "StateRoot" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "blockNumber" TEXT NOT NULL,
    "stateRoot" TEXT NOT NULL
);

-- CreateTable
CREATE TABLE "ConditionTx" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "objectId" TEXT NOT NULL,
    "condition" TEXT NOT NULL,
    "action" TEXT NOT NULL,
    "nextConditionAccount" TEXT NOT NULL,
    "actionTarget" TEXT NOT NULL,
    "completed" BOOLEAN NOT NULL DEFAULT false
);

-- CreateTable
CREATE TABLE "MPTProof" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "objectId" TEXT NOT NULL,
    "blockNumber" TEXT NOT NULL,
    "account" TEXT NOT NULL,
    "balance" TEXT NOT NULL
);

-- CreateTable
CREATE TABLE "Cursor" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "eventSeq" TEXT NOT NULL,
    "txDigest" TEXT NOT NULL
);

-- CreateIndex
CREATE UNIQUE INDEX "StateRoot_blockNumber_key" ON "StateRoot"("blockNumber");

-- CreateIndex
CREATE INDEX "StateRoot_blockNumber_idx" ON "StateRoot"("blockNumber");

-- CreateIndex
CREATE UNIQUE INDEX "ConditionTx_objectId_key" ON "ConditionTx"("objectId");

-- CreateIndex
CREATE INDEX "ConditionTx_completed_idx" ON "ConditionTx"("completed");

-- CreateIndex
CREATE UNIQUE INDEX "MPTProof_objectId_key" ON "MPTProof"("objectId");

-- CreateIndex
CREATE INDEX "MPTProof_blockNumber_idx" ON "MPTProof"("blockNumber");

-- CreateIndex
CREATE INDEX "MPTProof_account_idx" ON "MPTProof"("account");
