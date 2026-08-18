using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using BabcoUnloadCompare.Web.Models;

namespace BabcoUnloadCompare.Web.Services
{
    /// <summary>
    /// Exact live mapping for the Babco database structure supplied by the user.
    /// Header: dbo.UOS_Order(OrderId, OrderNo, SupplierName, ReceivedDate, ETA, ShippedOn, OrderDate)
    /// Detail: dbo.UOS_OrderDetail(OrderDetailId, OrderId, SKU, Qty, ItemName)
    /// Item:   dbo.Item(ItemId, SKU, ItemName, UnitsPerCase)
    ///
    /// No Web.config column mapping is required. The order is resolved to OrderId first,
    /// then details are loaded by that OrderId, aggregated by SKU, and zero/non-positive SKU totals are excluded. Item is only used
    /// to enrich PACKING/ItemName by SKU. Missing optional fields remain blank.
    /// </summary>
    public class BabcoOrderSource
    {
        private readonly string _supportConnectionString;
        private readonly string _appConnectionString;

        public BabcoOrderSource(string supportConnectionString, string appConnectionString)
        {
            _supportConnectionString = supportConnectionString;
            _appConnectionString = appConnectionString;
        }

        public List<PoSummary> Search(string search)
        {
            using (var cn = Open())
            {
                EnsureRequiredStructure(cn);

                const string sql = @"
SELECT TOP (30)
       CAST(o.OrderNo AS nvarchar(100)) AS PONumber,
       COALESCE(CAST(o.SupplierName AS nvarchar(200)), '') AS VendorName,
       CAST('' AS nvarchar(100)) AS ContainerNumber,
       COALESCE(o.ReceivedDate, o.ETA, o.ShippedOn, o.OrderDate) AS ReceivingDate,
       (SELECT COUNT(*)
          FROM
          (
              SELECT LTRIM(RTRIM(CAST(d.SKU AS nvarchar(80)))) AS SKU
              FROM dbo.UOS_OrderDetail d
              WHERE d.OrderId = o.OrderId
                AND NULLIF(LTRIM(RTRIM(CAST(d.SKU AS nvarchar(80)))), '') IS NOT NULL
              GROUP BY LTRIM(RTRIM(CAST(d.SKU AS nvarchar(80))))
              HAVING SUM(CONVERT(decimal(18,2), ISNULL(d.Qty, 0))) > 0
          ) positiveSku) AS ItemCount
FROM dbo.UOS_Order o
WHERE @Search = ''
   OR CAST(o.OrderNo AS nvarchar(100)) LIKE '%' + @Search + '%'
   OR COALESCE(CAST(o.SupplierName AS nvarchar(200)), '') LIKE '%' + @Search + '%'
ORDER BY o.OrderDate DESC, o.OrderId DESC;";

                var result = new List<PoSummary>();
                using (var cmd = new SqlCommand(sql, cn))
                {
                    cmd.CommandTimeout = 120;
                    cmd.Parameters.AddWithValue("@Search", (search ?? "").Trim());
                    using (var r = cmd.ExecuteReader())
                    {
                        while (r.Read())
                        {
                            result.Add(new PoSummary
                            {
                                PONumber = Convert.ToString(r["PONumber"]),
                                VendorName = Convert.ToString(r["VendorName"]),
                                ContainerNumber = Convert.ToString(r["ContainerNumber"]),
                                ReceivingDate = r["ReceivingDate"] == DBNull.Value ? (DateTime?)null : Convert.ToDateTime(r["ReceivingDate"]),
                                ItemCount = r["ItemCount"] == DBNull.Value ? 0 : Convert.ToInt32(r["ItemCount"])
                            });
                        }
                    }
                }
                return result;
            }
        }

        public PoLoadResult Load(string poNumber)
        {
            if (string.IsNullOrWhiteSpace(poNumber)) return null;

            using (var cn = Open())
            {
                EnsureRequiredStructure(cn);

                var result = new PoLoadResult { Items = new List<PoItemSource>() };
                long orderId;

                const string headerSql = @"
SELECT TOP (1)
       o.OrderId,
       CAST(o.OrderNo AS nvarchar(100)) AS PONumber,
       COALESCE(CAST(o.SupplierName AS nvarchar(200)), '') AS VendorName,
       CAST('' AS nvarchar(100)) AS ContainerNumber,
       COALESCE(o.ReceivedDate, o.ETA, o.ShippedOn, o.OrderDate) AS ReceivingDate
FROM dbo.UOS_Order o
WHERE CAST(o.OrderNo AS nvarchar(100)) = @PONumber
ORDER BY o.OrderId DESC;";

                using (var cmd = new SqlCommand(headerSql, cn))
                {
                    cmd.CommandTimeout = 120;
                    cmd.Parameters.AddWithValue("@PONumber", poNumber.Trim());
                    using (var r = cmd.ExecuteReader())
                    {
                        if (!r.Read()) return null;

                        orderId = Convert.ToInt64(r["OrderId"]);
                        result.Header = new PoSummary
                        {
                            PONumber = Convert.ToString(r["PONumber"]),
                            VendorName = Convert.ToString(r["VendorName"]),
                            ContainerNumber = Convert.ToString(r["ContainerNumber"]),
                            ReceivingDate = r["ReceivingDate"] == DBNull.Value ? (DateTime?)null : Convert.ToDateTime(r["ReceivingDate"])
                        };
                    }
                }

                // Important: filter detail rows by the resolved numeric OrderId, not by a guessed
                // detail key and not by OrderNo. This matches the supplied Babco schema exactly.
                // Aggregate by SKU so duplicate detail lines for the same order/SKU become one row.
                const string detailSql = @"
WITH DetailBySku AS
(
    SELECT
        LTRIM(RTRIM(CAST(d.SKU AS nvarchar(80)))) AS SKU,
        MAX(CAST(d.ItemName AS nvarchar(250))) AS DetailItemName,
        SUM(CONVERT(decimal(18,2), ISNULL(d.Qty, 0))) AS ExpectedQty
    FROM dbo.UOS_OrderDetail d
    WHERE d.OrderId = @OrderId
      AND NULLIF(LTRIM(RTRIM(CAST(d.SKU AS nvarchar(80)))), '') IS NOT NULL
    GROUP BY LTRIM(RTRIM(CAST(d.SKU AS nvarchar(80))))
    HAVING SUM(CONVERT(decimal(18,2), ISNULL(d.Qty, 0))) > 0
)
SELECT
    dd.SKU,
    COALESCE(NULLIF(itemx.ItemName, ''), NULLIF(dd.DetailItemName, ''), '') AS ItemName,
    dd.ExpectedQty,
    CAST('' AS nvarchar(30)) AS UOM
FROM DetailBySku dd
OUTER APPLY
(
    SELECT TOP (1)
           CAST(i.ItemName AS nvarchar(250)) AS ItemName
    FROM dbo.Item i
    WHERE LTRIM(RTRIM(CAST(i.SKU AS nvarchar(80)))) = dd.SKU
    ORDER BY i.ItemId
) itemx
ORDER BY dd.SKU;";

                using (var cmd = new SqlCommand(detailSql, cn))
                {
                    cmd.CommandTimeout = 120;
                    cmd.Parameters.AddWithValue("@OrderId", orderId);
                    using (var r = cmd.ExecuteReader())
                    {
                        while (r.Read())
                        {
                            result.Items.Add(new PoItemSource
                            {
                                SKU = Convert.ToString(r["SKU"]),
                                ItemName = Convert.ToString(r["ItemName"]),
                                ExpectedQty = r["ExpectedQty"] == DBNull.Value ? 0 : Convert.ToDecimal(r["ExpectedQty"]),
                                UOM = Convert.ToString(r["UOM"]),
                                ExpectedPallets = null
                            });
                        }
                    }
                }

                result.Header.ItemCount = result.Items.Count;
                result.ExistingReceivingId = ExistingReceivingId(result.Header.PONumber);
                return result;
            }
        }

        public string GetMappingDiagnostic()
        {
            return "Exact Babco mapping: UOS_Order.OrderId -> UOS_OrderDetail.OrderId; " +
                   "PO=UOS_Order.OrderNo; Vendor=UOS_Order.SupplierName; " +
                   "SKU=UOS_OrderDetail.SKU; SHIP QTY=SUM(UOS_OrderDetail.Qty) by OrderId+SKU; only SKU totals > 0 are loaded; " +
                   "PACKING=Item.ItemName joined by SKU, fallback UOS_OrderDetail.ItemName; " +
                   "missing optional receiving fields stay blank. No Web.config column mapping is required.";
        }

        private SqlConnection Open()
        {
            var cn = new SqlConnection(_supportConnectionString);
            cn.Open();
            return cn;
        }

        private static void EnsureRequiredStructure(SqlConnection cn)
        {
            const string sql = @"
SELECT
    CASE WHEN OBJECT_ID('dbo.UOS_Order','U') IS NOT NULL THEN 1 ELSE 0 END AS HasOrder,
    CASE WHEN OBJECT_ID('dbo.UOS_OrderDetail','U') IS NOT NULL THEN 1 ELSE 0 END AS HasDetail,
    CASE WHEN OBJECT_ID('dbo.Item','U') IS NOT NULL THEN 1 ELSE 0 END AS HasItem,
    CASE WHEN COL_LENGTH('dbo.UOS_Order','OrderId') IS NOT NULL THEN 1 ELSE 0 END AS HasOrderId,
    CASE WHEN COL_LENGTH('dbo.UOS_Order','OrderNo') IS NOT NULL THEN 1 ELSE 0 END AS HasOrderNo,
    CASE WHEN COL_LENGTH('dbo.UOS_OrderDetail','OrderId') IS NOT NULL THEN 1 ELSE 0 END AS HasDetailOrderId,
    CASE WHEN COL_LENGTH('dbo.UOS_OrderDetail','SKU') IS NOT NULL THEN 1 ELSE 0 END AS HasDetailSku,
    CASE WHEN COL_LENGTH('dbo.UOS_OrderDetail','Qty') IS NOT NULL THEN 1 ELSE 0 END AS HasDetailQty,
    CASE WHEN COL_LENGTH('dbo.Item','SKU') IS NOT NULL THEN 1 ELSE 0 END AS HasItemSku,
    CASE WHEN COL_LENGTH('dbo.Item','ItemName') IS NOT NULL THEN 1 ELSE 0 END AS HasItemName;";

            using (var cmd = new SqlCommand(sql, cn))
            using (var r = cmd.ExecuteReader())
            {
                if (!r.Read())
                    throw new InvalidOperationException("Unable to validate the Babco order source schema.");

                if (Convert.ToInt32(r["HasOrder"]) != 1 || Convert.ToInt32(r["HasDetail"]) != 1)
                    throw new InvalidOperationException("Required Babco tables dbo.UOS_Order and dbo.UOS_OrderDetail were not found.");

                if (Convert.ToInt32(r["HasOrderId"]) != 1 || Convert.ToInt32(r["HasOrderNo"]) != 1 ||
                    Convert.ToInt32(r["HasDetailOrderId"]) != 1 || Convert.ToInt32(r["HasDetailSku"]) != 1 ||
                    Convert.ToInt32(r["HasDetailQty"]) != 1)
                    throw new InvalidOperationException("Babco order schema does not match the required structure: UOS_Order(OrderId,OrderNo) and UOS_OrderDetail(OrderId,SKU,Qty).");

                // dbo.Item is enrichment only. If the table/columns are unavailable, the SQL below
                // would fail, so surface one clear message instead of silently guessing mappings.
                if (Convert.ToInt32(r["HasItem"]) != 1 || Convert.ToInt32(r["HasItemSku"]) != 1 || Convert.ToInt32(r["HasItemName"]) != 1)
                    throw new InvalidOperationException("Required item lookup structure dbo.Item(SKU, ItemName) was not found.");
            }
        }

        private int? ExistingReceivingId(string po)
        {
            using (var cn = new SqlConnection(_appConnectionString))
            {
                cn.Open();
                using (var cmd = new SqlCommand(@"IF OBJECT_ID('dbo.UC_ReceivingHeader','U') IS NULL SELECT CAST(NULL AS int)
ELSE SELECT TOP (1) ReceivingId FROM dbo.UC_ReceivingHeader WHERE PONumber=@PO AND Status IN('Draft','In Progress','Ready for Verification') ORDER BY ModifiedDate DESC;", cn))
                {
                    cmd.Parameters.AddWithValue("@PO", po);
                    var value = cmd.ExecuteScalar();
                    return value == null || value == DBNull.Value ? (int?)null : Convert.ToInt32(value);
                }
            }
        }
    }
}
