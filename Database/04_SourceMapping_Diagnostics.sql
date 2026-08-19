USE [Babco];
GO
PRINT 'Unload Compare - confirmed Babco schema visibility. No Web.config column setup is required.';
PRINT 'Exact mapping: UOS_Order.OrderId = UOS_OrderDetail.OrderId; PO = UOS_Order.OrderNo; SKU = UOS_OrderDetail.SKU; SHIP QTY = UOS_OrderDetail.Qty; PACKING = Item.ItemName by SKU.';
GO
SELECT CASE WHEN OBJECT_ID('dbo.UOS_Order','U') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS UOS_Order, CASE WHEN OBJECT_ID('dbo.UOS_OrderDetail','U') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS UOS_OrderDetail, CASE WHEN OBJECT_ID('dbo.Item','U') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS Item;
GO
