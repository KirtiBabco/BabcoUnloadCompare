/*
  Babco Unload Compare v1.2.0 - existing APPLICATION database upgrade.
  Run this against the database configured by UnloadCompareConnectionString.
  Safe/additive: no existing data is deleted.
*/
SET XACT_ABORT ON;
GO
IF OBJECT_ID('dbo.UC_ReceivingHeader','U') IS NULL
    THROW 51000, 'UC_ReceivingHeader does not exist. Run 01_Schema.sql first.', 1;
GO
IF COL_LENGTH('dbo.UC_ReceivingHeader','UnloadDate') IS NULL
    ALTER TABLE dbo.UC_ReceivingHeader ADD UnloadDate date NULL;
GO
IF COL_LENGTH('dbo.UC_ReceivingHeader','UnloadBy1') IS NULL
    ALTER TABLE dbo.UC_ReceivingHeader ADD UnloadBy1 nvarchar(150) NULL;
GO
IF COL_LENGTH('dbo.UC_ReceivingHeader','UnloadBy2') IS NULL
    ALTER TABLE dbo.UC_ReceivingHeader ADD UnloadBy2 nvarchar(150) NULL;
GO
IF COL_LENGTH('dbo.UC_ReceivingHeader','UnloadBy3') IS NULL
    ALTER TABLE dbo.UC_ReceivingHeader ADD UnloadBy3 nvarchar(150) NULL;
GO
SELECT 'v1.2.0 header columns ready. Now run 02_StoredProcedures.sql.' AS Result;
GO
