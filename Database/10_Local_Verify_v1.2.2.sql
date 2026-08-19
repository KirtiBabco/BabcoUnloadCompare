/* Babco Unload Compare v1.2.2 local verification */
SELECT DB_NAME() AS CurrentDatabase;
SELECT OBJECT_ID('dbo.UC_Receiving','U') AS UC_Receiving_ObjectId, OBJECT_ID('dbo.UC_ReceivingItem','U') AS UC_ReceivingItem_ObjectId, OBJECT_ID('dbo.UC_SchemaVersion','U') AS UC_SchemaVersion_ObjectId;
IF OBJECT_ID('dbo.UC_SchemaVersion','U') IS NOT NULL SELECT * FROM dbo.UC_SchemaVersion ORDER BY AppliedDate DESC;
