USE [Babco];
GO

/*
  Babco Unload Compare - exact source query test.
  Set @OrderNo to the PO/order number searched on UnloadCompare.aspx.
  If left NULL, the script picks the latest order that has detail rows.
*/
DECLARE @OrderNo nvarchar(100) = NULL; -- Example: N'AB-CA-12'
DECLARE @OrderId bigint;

IF NULLIF(LTRIM(RTRIM(@OrderNo)), N'') IS NULL
BEGIN
    SELECT TOP (1)
           @OrderId = o.OrderId,
           @OrderNo = CAST(o.OrderNo AS nvarchar(100))
    FROM dbo.UOS_Order o
    WHERE EXISTS (SELECT 1 FROM dbo.UOS_OrderDetail d WHERE d.OrderId = o.OrderId)
    ORDER BY o.OrderDate DESC, o.OrderId DESC;
END
ELSE
BEGIN
    SELECT TOP (1) @OrderId = o.OrderId
    FROM dbo.UOS_Order o
    WHERE CAST(o.OrderNo AS nvarchar(100)) = @OrderNo
    ORDER BY o.OrderId DESC;
END;

SELECT @OrderId AS ResolvedOrderId, @OrderNo AS ResolvedOrderNo;

SELECT TOP (1)
       o.OrderId,
       o.OrderNo,
       o.OrderDate,
       o.SupplierId,
       o.SupplierName,
       o.ETA,
       o.ShippedOn,
       o.ReceivedDate,
       o.Status,
       o.Brand,
       o.CasesOrdered
FROM dbo.UOS_Order o
WHERE o.OrderId = @OrderId;

WITH DetailBySku AS
(
    SELECT
        LTRIM(RTRIM(CAST(d.SKU AS nvarchar(80)))) AS SKU,
        MAX(CAST(d.ItemName AS nvarchar(250))) AS DetailItemName,
        SUM(CONVERT(decimal(18,2), ISNULL(d.Qty, 0))) AS ShipQty
    FROM dbo.UOS_OrderDetail d
    WHERE d.OrderId = @OrderId
      AND NULLIF(LTRIM(RTRIM(CAST(d.SKU AS nvarchar(80)))), '') IS NOT NULL
    GROUP BY LTRIM(RTRIM(CAST(d.SKU AS nvarchar(80))))
)
SELECT
    dd.SKU,
    COALESCE(NULLIF(itemx.ItemName, ''), NULLIF(dd.DetailItemName, ''), '') AS PACKING,
    dd.ShipQty AS [SHIP QTY],
    CAST(NULL AS decimal(18,2)) AS [REC QTY],
    CAST(NULL AS nvarchar(30)) AS [Expiry date],
    CAST(NULL AS nvarchar(50)) AS Nitrogen,
    CAST(NULL AS decimal(18,2)) AS [DIFF (+/-)],
    CAST(NULL AS decimal(18,2)) AS [PAL-1],
    CAST(NULL AS decimal(18,2)) AS [PAL-2],
    CAST(NULL AS decimal(18,2)) AS [PAL-3],
    CAST(NULL AS decimal(18,2)) AS [PAL-4],
    CAST(NULL AS decimal(18,2)) AS [PAL-5],
    CAST(NULL AS decimal(18,2)) AS TOTAL
FROM DetailBySku dd
OUTER APPLY
(
    SELECT TOP (1)
           CAST(i.ItemName AS nvarchar(250)) AS ItemName
    FROM dbo.Item i
    WHERE LTRIM(RTRIM(CAST(i.SKU AS nvarchar(80)))) = dd.SKU
    ORDER BY i.ItemId
) itemx
ORDER BY dd.SKU;
GO
