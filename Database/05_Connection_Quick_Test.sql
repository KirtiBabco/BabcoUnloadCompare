USE [Babco];
GO
SELECT DB_NAME() AS CurrentDatabase;
SELECT COUNT(*) AS UOS_Order_Count FROM dbo.UOS_Order;
SELECT COUNT(*) AS UOS_OrderDetail_Count FROM dbo.UOS_OrderDetail;
SELECT COUNT(*) AS Item_Count FROM dbo.Item;
SELECT TOP (10) * FROM dbo.UOS_Order ORDER BY 1 DESC;
GO
