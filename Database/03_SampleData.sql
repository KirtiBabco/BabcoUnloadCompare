USE [Babco];
GO
/*
  No fake PO/order rows are inserted in v1.2.0.
  Unload Compare now reads live order data from:
    dbo.UOS_Order
    dbo.UOS_OrderDetail
    dbo.Item

  The UC_POHeaderSource and UC_POItemSource tables are internal validation/cache tables.
  They are refreshed automatically when a PO is loaded from the application.
*/
SELECT 'No sample order data inserted. Live Babco order tables are used.' AS Result;
GO
