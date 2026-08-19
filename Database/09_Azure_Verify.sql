SET NOCOUNT ON;
SELECT DB_NAME() AS DatabaseName;
SELECT VersionNo, AppliedDate FROM dbo.UC_SchemaVersion ORDER BY AppliedDate DESC;
SELECT name AS RequiredTable FROM sys.tables WHERE name IN ('UC_ReceivingHeader','UC_ReceivingItem','UC_ReceivingPallet','UC_UploadedDocument','UC_ImportHistory','UC_Verification','UC_AuditLog','UC_POHeaderSource','UC_POItemSource','UOS_Order','UOS_OrderDetail','Item') ORDER BY name;
SELECT name AS RequiredProcedure FROM sys.procedures WHERE name LIKE 'usp_UC_%' ORDER BY name;
