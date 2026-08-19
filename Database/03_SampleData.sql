USE [Babco];
GO
/* No fake PO/order rows are inserted. Unload Compare reads live order data from dbo.UOS_Order, dbo.UOS_OrderDetail and dbo.Item. */
SELECT 'No sample order data inserted. Live Babco order tables are used.' AS Result;
GO
