using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using BabcoUnloadCompare.Web.Services;

namespace BabcoUnloadCompare.Web.Handlers
{
    public class ExcelExport : IHttpHandler
    {
        public bool IsReusable { get { return false; } }

        public void ProcessRequest(HttpContext context)
        {
            int receivingId;
            if (!int.TryParse(context.Request.QueryString["id"], out receivingId))
            {
                context.Response.StatusCode = 400;
                return;
            }

            var details = new DataAccess().GetDetails(receivingId);
            if (details == null)
            {
                context.Response.StatusCode = 404;
                return;
            }

            const int maxPallet = 5;
            var rows = new List<List<object>>();
            var header = new List<object>
            {
                "SKU", "PACKING", "SHIP QTY", "REC QTY", "Expiry date", "Nitrogen", "DIFF ( +/-)"
            };
            for (int i = 1; i <= maxPallet; i++) header.Add("PAL-" + i);
            header.Add("TOTAL");
            rows.Add(header);

            decimal shipTotal = 0, recTotal = 0, diffTotal = 0;
            var palletTotals = new decimal[maxPallet];
            decimal palletGrandTotal = 0;
            bool allEntered = details.Items.Count > 0;
            int excelRow = 2;

            foreach (var item in details.Items)
            {
                shipTotal += item.ExpectedQty;
                bool hasPallet = item.Pallets != null && item.Pallets.Any(x => x.PalletNo >= 1 && x.PalletNo <= maxPallet);
                bool hasManual = item.ManualPhysicalQty.HasValue;
                bool entered = hasPallet || hasManual;
                allEntered = allEntered && entered;

                decimal palletTotal = 0;
                if (hasPallet)
                    palletTotal = item.Pallets.Where(x => x.PalletNo >= 1 && x.PalletNo <= maxPallet).Sum(x => x.Quantity);

                decimal received = hasPallet ? palletTotal : (hasManual ? item.ManualPhysicalQty.Value : 0m);
                decimal difference = received - item.ExpectedQty;
                if (entered)
                {
                    recTotal += received;
                    diffTotal += difference;
                }

                var row = new List<object>
                {
                    item.SKU,
                    item.ItemName,
                    item.ExpectedQty,
                    entered ? (object)received : "",
                    item.ExpiryDate ?? "",
                    item.Nitrogen ?? "",
                    SimpleXlsxWriter.Fx("IF(D" + excelRow + "<>\"\",D" + excelRow + "-C" + excelRow + ",IF(M" + excelRow + "<>\"\",M" + excelRow + "-C" + excelRow + ",\"\"))")
                };

                for (int i = 1; i <= maxPallet; i++)
                {
                    var pallet = item.Pallets == null ? null : item.Pallets.FirstOrDefault(x => x.PalletNo == i);
                    if (pallet == null) row.Add("");
                    else
                    {
                        row.Add(pallet.Quantity);
                        palletTotals[i - 1] += pallet.Quantity;
                    }
                }
                row.Add(SimpleXlsxWriter.Fx("IF(COUNTA(H" + excelRow + ":L" + excelRow + ")=0,\"\",SUM(H" + excelRow + ":L" + excelRow + "))"));
                if (hasPallet) palletGrandTotal += palletTotal;
                rows.Add(row);
                excelRow++;
            }

            var totalRow = new List<object>
            {
                "ORDER TOTAL", "", shipTotal, recTotal == 0m && !details.Items.Any(x => x.ManualPhysicalQty.HasValue || (x.Pallets != null && x.Pallets.Count > 0)) ? (object)"" : recTotal,
                "", "", allEntered ? (object)diffTotal : ""
            };
            for (int i = 0; i < maxPallet; i++) totalRow.Add(palletTotals[i] == 0 ? (object)"" : palletTotals[i]);
            totalRow.Add(palletGrandTotal == 0 ? (object)"" : palletGrandTotal);
            rows.Add(totalRow);

            byte[] bytes = SimpleXlsxWriter.Write(rows);
            var poSafe = string.Join("_", (details.Header.PONumber ?? "PO").Split(PathInvalidChars()));
            context.Response.Clear();
            context.Response.ContentType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
            context.Response.AddHeader("Content-Disposition", "attachment; filename=UnloadCompare_" + poSafe + "_FillAndUpload.xlsx");
            context.Response.OutputStream.Write(bytes, 0, bytes.Length);
            context.Response.Flush();
            context.ApplicationInstance.CompleteRequest();
        }

        private static char[] PathInvalidChars()
        {
            return new[] { '\\', '/', ':', '*', '?', '"', '<', '>', '|' };
        }
    }
}
