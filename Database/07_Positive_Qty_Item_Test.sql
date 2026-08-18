USE [Babco];
GO

DECLARE @OrderNo nvarchar(100) = N'KO-CA-03';
DECLARE @OrderId bigint;

SELECT TOP (1) @OrderId = OrderId
FROM dbo.UOS_Order
WHERE CAST(OrderNo AS nvarchar(100)) = @OrderNo
ORDER BY OrderId DESC;

SELECT
    LTRIM(RTRIM(CAST(d.SKU AS nvarchar(80)))) AS SKU,
    SUM(CONVERT(decimal(18,2), ISNULL(d.Qty, 0))) AS ShipQty
FROM dbo.UOS_OrderDetail d
WHERE d.OrderId = @OrderId
  AND NULLIF(LTRIM(RTRIM(CAST(d.SKU AS nvarchar(80)))), '') IS NOT NULL
GROUP BY LTRIM(RTRIM(CAST(d.SKU AS nvarchar(80))))
HAVING SUM(CONVERT(decimal(18,2), ISNULL(d.Qty, 0))) > 0
ORDER BY SKU;

-- Validation: this must return zero rows.
SELECT
    LTRIM(RTRIM(CAST(d.SKU AS nvarchar(80)))) AS InvalidSKU,
    SUM(CONVERT(decimal(18,2), ISNULL(d.Qty, 0))) AS ShipQty
FROM dbo.UOS_OrderDetail d
WHERE d.OrderId = @OrderId
  AND NULLIF(LTRIM(RTRIM(CAST(d.SKU AS nvarchar(80)))), '') IS NOT NULL
GROUP BY LTRIM(RTRIM(CAST(d.SKU AS nvarchar(80))))
HAVING SUM(CONVERT(decimal(18,2), ISNULL(d.Qty, 0))) <= 0;
GO
