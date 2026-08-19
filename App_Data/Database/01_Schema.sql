-- Run against the Unload Compare APPLICATION database (local or Azure).
-- Supporting Babco UOS tables remain in BabcoSupportConnectionString and are not created here.
GO
SET XACT_ABORT ON;
GO
IF OBJECT_ID('dbo.UC_POHeaderSource','U') IS NULL
BEGIN
 CREATE TABLE dbo.UC_POHeaderSource(PONumber nvarchar(50) NOT NULL PRIMARY KEY,VendorName nvarchar(200) NOT NULL,ContainerNumber nvarchar(100) NULL,ReceivingDate date NULL,IsActive bit NOT NULL CONSTRAINT DF_UC_POHeader_Active DEFAULT(1));
END
GO
IF OBJECT_ID('dbo.UC_POItemSource','U') IS NULL
BEGIN
 CREATE TABLE dbo.UC_POItemSource(POItemId int IDENTITY(1,1) PRIMARY KEY,PONumber nvarchar(50) NOT NULL,SKU nvarchar(80) NOT NULL,ItemName nvarchar(250) NOT NULL,ExpectedQty decimal(18,2) NOT NULL,UOM nvarchar(30) NULL,ExpectedPallets int NULL,CONSTRAINT UQ_UC_POItem UNIQUE(PONumber,SKU));
END
GO
IF OBJECT_ID('dbo.UC_ReceivingHeader','U') IS NULL
BEGIN
 CREATE TABLE dbo.UC_ReceivingHeader(ReceivingId int IDENTITY(1,1) PRIMARY KEY,PONumber nvarchar(50) NOT NULL,VendorName nvarchar(200) NULL,ContainerNumber nvarchar(100) NULL,ReceivingDate date NOT NULL,UnloadDate date NULL,UnloadBy1 nvarchar(150) NULL,UnloadBy2 nvarchar(150) NULL,UnloadBy3 nvarchar(150) NULL,Status nvarchar(40) NOT NULL CONSTRAINT DF_UC_RH_Status DEFAULT('Draft'),Notes nvarchar(max) NULL,CreatedBy nvarchar(150) NOT NULL,CreatedDate datetime2 NOT NULL CONSTRAINT DF_UC_RH_Created DEFAULT(sysdatetime()),ModifiedBy nvarchar(150) NOT NULL,ModifiedDate datetime2 NOT NULL CONSTRAINT DF_UC_RH_Modified DEFAULT(sysdatetime()),VerifiedBy nvarchar(150) NULL,VerifiedDate datetime2 NULL,VerificationNotes nvarchar(max) NULL);
END
GO
IF COL_LENGTH('dbo.UC_ReceivingHeader','UnloadDate') IS NULL ALTER TABLE dbo.UC_ReceivingHeader ADD UnloadDate date NULL;
GO
IF COL_LENGTH('dbo.UC_ReceivingHeader','UnloadBy1') IS NULL ALTER TABLE dbo.UC_ReceivingHeader ADD UnloadBy1 nvarchar(150) NULL;
GO
IF COL_LENGTH('dbo.UC_ReceivingHeader','UnloadBy2') IS NULL ALTER TABLE dbo.UC_ReceivingHeader ADD UnloadBy2 nvarchar(150) NULL;
GO
IF COL_LENGTH('dbo.UC_ReceivingHeader','UnloadBy3') IS NULL ALTER TABLE dbo.UC_ReceivingHeader ADD UnloadBy3 nvarchar(150) NULL;
GO
IF OBJECT_ID('dbo.UC_ReceivingItem','U') IS NULL
BEGIN
 CREATE TABLE dbo.UC_ReceivingItem(ReceivingItemId int IDENTITY(1,1) PRIMARY KEY,ReceivingId int NOT NULL,SKU nvarchar(80) NOT NULL,ItemName nvarchar(250) NOT NULL,ExpectedQty decimal(18,2) NOT NULL,UOM nvarchar(30) NULL,EntryMode nvarchar(20) NOT NULL CONSTRAINT DF_UC_RI_Mode DEFAULT('Pallet'),ManualPhysicalQty decimal(18,2) NULL,ExpiryDate nvarchar(30) NULL,Nitrogen nvarchar(100) NULL,TotalPhysicalQty decimal(18,2) NOT NULL CONSTRAINT DF_UC_RI_Physical DEFAULT(0),DifferenceQty decimal(18,2) NOT NULL CONSTRAINT DF_UC_RI_Diff DEFAULT(0),CompareStatus nvarchar(20) NOT NULL CONSTRAINT DF_UC_RI_Status DEFAULT('Short'),Notes nvarchar(max) NULL,ModifiedBy nvarchar(150) NULL,ModifiedDate datetime2 NOT NULL CONSTRAINT DF_UC_RI_Modified DEFAULT(sysdatetime()),CONSTRAINT FK_UC_RI_RH FOREIGN KEY(ReceivingId) REFERENCES dbo.UC_ReceivingHeader(ReceivingId),CONSTRAINT UQ_UC_RI UNIQUE(ReceivingId,SKU));
END
GO
IF COL_LENGTH('dbo.UC_ReceivingItem','ExpectedPallets') IS NULL ALTER TABLE dbo.UC_ReceivingItem ADD ExpectedPallets int NULL;
GO
IF COL_LENGTH('dbo.UC_ReceivingItem','ExpiryDate') IS NULL ALTER TABLE dbo.UC_ReceivingItem ADD ExpiryDate nvarchar(30) NULL;
GO
IF COL_LENGTH('dbo.UC_ReceivingItem','Nitrogen') IS NULL ALTER TABLE dbo.UC_ReceivingItem ADD Nitrogen nvarchar(100) NULL;
GO
IF OBJECT_ID('dbo.UC_ReceivingPallet','U') IS NULL
BEGIN
 CREATE TABLE dbo.UC_ReceivingPallet(PalletId int IDENTITY(1,1) PRIMARY KEY,ReceivingItemId int NOT NULL,PalletNo int NOT NULL,Quantity decimal(18,2) NOT NULL,CreatedBy nvarchar(150) NOT NULL,CreatedDate datetime2 NOT NULL CONSTRAINT DF_UC_RP_Created DEFAULT(sysdatetime()),CONSTRAINT FK_UC_RP_RI FOREIGN KEY(ReceivingItemId) REFERENCES dbo.UC_ReceivingItem(ReceivingItemId),CONSTRAINT UQ_UC_RP UNIQUE(ReceivingItemId,PalletNo));
END
GO
IF OBJECT_ID('dbo.UC_UploadedDocument','U') IS NULL
BEGIN
 CREATE TABLE dbo.UC_UploadedDocument(DocumentId int IDENTITY(1,1) PRIMARY KEY,ReceivingId int NOT NULL,OriginalFileName nvarchar(260) NOT NULL,StoredFileName nvarchar(260) NOT NULL,ContentType nvarchar(120) NULL,FileSizeBytes bigint NOT NULL,ExtractionStatus nvarchar(40) NOT NULL CONSTRAINT DF_UC_Doc_Extraction DEFAULT('Pending Review'),ExtractionJson nvarchar(max) NULL,UploadedBy nvarchar(150) NOT NULL,UploadedDate datetime2 NOT NULL CONSTRAINT DF_UC_Doc_Date DEFAULT(sysdatetime()),CONSTRAINT FK_UC_Doc_RH FOREIGN KEY(ReceivingId) REFERENCES dbo.UC_ReceivingHeader(ReceivingId));
END
GO
IF OBJECT_ID('dbo.UC_ImportHistory','U') IS NULL
BEGIN
 CREATE TABLE dbo.UC_ImportHistory(ImportId int IDENTITY(1,1) PRIMARY KEY,ReceivingId int NOT NULL,FileName nvarchar(260) NOT NULL,TotalRows int NOT NULL,MatchedRows int NOT NULL,UnmatchedRows int NOT NULL,ImportStatus nvarchar(40) NOT NULL,Details nvarchar(max) NULL,ImportedBy nvarchar(150) NOT NULL,ImportedDate datetime2 NOT NULL CONSTRAINT DF_UC_Import_Date DEFAULT(sysdatetime()),CONSTRAINT FK_UC_Import_RH FOREIGN KEY(ReceivingId) REFERENCES dbo.UC_ReceivingHeader(ReceivingId));
END
GO
IF OBJECT_ID('dbo.UC_Verification','U') IS NULL
BEGIN
 CREATE TABLE dbo.UC_Verification(VerificationId int IDENTITY(1,1) PRIMARY KEY,ReceivingId int NOT NULL,VerificationStatus nvarchar(30) NOT NULL,Comments nvarchar(max) NULL,VerifiedBy nvarchar(150) NOT NULL,VerifiedDate datetime2 NOT NULL CONSTRAINT DF_UC_Ver_Date DEFAULT(sysdatetime()),CONSTRAINT FK_UC_Ver_RH FOREIGN KEY(ReceivingId) REFERENCES dbo.UC_ReceivingHeader(ReceivingId));
END
GO
IF OBJECT_ID('dbo.UC_AuditLog','U') IS NULL
BEGIN
 CREATE TABLE dbo.UC_AuditLog(AuditId bigint IDENTITY(1,1) PRIMARY KEY,ReceivingId int NOT NULL,EntityType nvarchar(50) NOT NULL,EntityId int NULL,ActionType nvarchar(50) NOT NULL,FieldName nvarchar(100) NULL,OldValue nvarchar(max) NULL,NewValue nvarchar(max) NULL,ChangedBy nvarchar(150) NOT NULL,ChangedDate datetime2 NOT NULL CONSTRAINT DF_UC_Audit_Date DEFAULT(sysdatetime()));
END
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_UC_RH_PO_Status' AND object_id=OBJECT_ID('dbo.UC_ReceivingHeader')) CREATE INDEX IX_UC_RH_PO_Status ON dbo.UC_ReceivingHeader(PONumber,Status,ModifiedDate DESC);
GO
