/*
 Babco Unload Compare v1.2.1 - TEMPORARY Azure support-source compatibility schema.
 Purpose: both Azure environment variables initially point to the same Azure SQL DB.
 Later, change only BabcoSupportConnectionString to the live Babco SQL database.
 These tables are additive placeholders only; no sample order data is inserted.
*/
SET XACT_ABORT ON;
GO
IF OBJECT_ID('dbo.UOS_Order','U') IS NULL
BEGIN
    CREATE TABLE dbo.UOS_Order
    (
        OrderId bigint NOT NULL CONSTRAINT PK_UOS_Order_AzurePlaceholder PRIMARY KEY,
        OrderNo nvarchar(100) NOT NULL,
        OrderDate datetime2 NULL,
        SupplierName nvarchar(200) NULL,
        ShippedOn datetime2 NULL,
        ETA datetime2 NULL,
        ReceivedDate datetime2 NULL
    );
    CREATE INDEX IX_UOS_Order_OrderNo ON dbo.UOS_Order(OrderNo);
END
GO
IF OBJECT_ID('dbo.UOS_OrderDetail','U') IS NULL
BEGIN
    CREATE TABLE dbo.UOS_OrderDetail
    (
        OrderDetailId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_UOS_OrderDetail_AzurePlaceholder PRIMARY KEY,
        OrderId bigint NOT NULL,
        SKU nvarchar(80) NULL,
        Qty decimal(18,2) NULL,
        ItemName nvarchar(250) NULL
    );
    CREATE INDEX IX_UOS_OrderDetail_OrderId_SKU ON dbo.UOS_OrderDetail(OrderId, SKU);
END
GO
IF OBJECT_ID('dbo.Item','U') IS NULL
BEGIN
    CREATE TABLE dbo.Item
    (
        ItemId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Item_AzurePlaceholder PRIMARY KEY,
        SKU nvarchar(80) NOT NULL,
        ItemName nvarchar(250) NULL
    );
    CREATE INDEX IX_Item_SKU ON dbo.Item(SKU);
END
GO
