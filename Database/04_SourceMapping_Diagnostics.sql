USE [Babco];
GO
PRINT 'Unload Compare v1.1.7 - confirmed Babco schema visibility. No Web.config column setup is required.';
PRINT 'Exact mapping: UOS_Order.OrderId = UOS_OrderDetail.OrderId; PO = UOS_Order.OrderNo; SKU = UOS_OrderDetail.SKU; SHIP QTY = UOS_OrderDetail.Qty; PACKING = Item.ItemName by SKU.';
GO
PRINT '=== UOS_Order columns ===';
SELECT c.column_id,c.name AS ColumnName,t.name AS DataType,c.max_length,c.is_nullable
FROM sys.columns c JOIN sys.types t ON c.user_type_id=t.user_type_id
WHERE c.object_id=OBJECT_ID('dbo.UOS_Order') ORDER BY c.column_id;
GO
PRINT '=== UOS_OrderDetail columns ===';
SELECT c.column_id,c.name AS ColumnName,t.name AS DataType,c.max_length,c.is_nullable
FROM sys.columns c JOIN sys.types t ON c.user_type_id=t.user_type_id
WHERE c.object_id=OBJECT_ID('dbo.UOS_OrderDetail') ORDER BY c.column_id;
GO
PRINT '=== Item columns (SKU -> ItemName PACKING lookup) ===';
SELECT c.column_id,c.name AS ColumnName,t.name AS DataType,c.max_length,c.is_nullable
FROM sys.columns c JOIN sys.types t ON c.user_type_id=t.user_type_id
WHERE c.object_id=OBJECT_ID('dbo.Item') ORDER BY c.column_id;
GO
SELECT
  CASE WHEN OBJECT_ID('dbo.UOS_Order','U') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS UOS_Order,
  CASE WHEN OBJECT_ID('dbo.UOS_OrderDetail','U') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS UOS_OrderDetail,
  CASE WHEN COL_LENGTH('dbo.UOS_OrderDetail','OrderId') IS NOT NULL THEN 'OK' ELSE 'CHECK LINK' END AS Detail_OrderId,
  CASE WHEN COL_LENGTH('dbo.UOS_OrderDetail','SKU') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS Detail_SKU,
  CASE WHEN COL_LENGTH('dbo.UOS_OrderDetail','Qty') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS Detail_Qty,
  CASE WHEN COL_LENGTH('dbo.UOS_OrderDetail','ItemName') IS NOT NULL THEN 'AVAILABLE' ELSE 'BLANK/FROM ITEM' END AS Detail_ItemName,
  CASE WHEN COL_LENGTH('dbo.UOS_Order','OrderId') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS Header_OrderId,
  CASE WHEN COL_LENGTH('dbo.UOS_Order','OrderNo') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS Header_OrderNo,
  CASE WHEN OBJECT_ID('dbo.Item','U') IS NOT NULL AND COL_LENGTH('dbo.Item','SKU') IS NOT NULL AND COL_LENGTH('dbo.Item','ItemName') IS NOT NULL THEN 'OK' ELSE 'MISSING/FALLBACK DETAIL NAME' END AS Item_SKU_Name;
GO
