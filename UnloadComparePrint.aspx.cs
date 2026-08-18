using System;
using System.Linq;
using System.Text;
using BabcoUnloadCompare.Web.Services;

namespace BabcoUnloadCompare.Web
{
    public partial class UnloadComparePrint : System.Web.UI.Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            int receivingId;
            if (!int.TryParse(Request.QueryString["id"], out receivingId))
            {
                ReportHtml.Text = "Invalid receiving id.";
                return;
            }

            var details = new DataAccess().GetDetails(receivingId);
            if (details == null)
            {
                ReportHtml.Text = "Receiving record not found.";
                return;
            }

            const int maxPallet = 5;

            var b = new StringBuilder();
            b.Append("<div class='meta'>")
             .Append("<div><small>PO</small>").Append(E(details.Header.PONumber)).Append("</div>")
             .Append("<div><small>Vendor</small>").Append(E(details.Header.VendorName)).Append("</div>")
             .Append("<div><small>Container</small>").Append(E(details.Header.ContainerNumber)).Append("</div>")
             .Append("<div><small>Receiving Date</small>").Append(details.Header.ReceivingDate.ToString("yyyy-MM-dd")).Append("</div>")
             .Append("<div><small>Unload Date</small>").Append(details.Header.UnloadDate.HasValue ? details.Header.UnloadDate.Value.ToString("yyyy-MM-dd") : "").Append("</div>")
             .Append("<div><small>Unload By 1</small>").Append(E(details.Header.UnloadBy1)).Append("</div>")
             .Append("<div><small>Unload By 2</small>").Append(E(details.Header.UnloadBy2)).Append("</div>")
             .Append("<div><small>Unload By 3</small>").Append(E(details.Header.UnloadBy3)).Append("</div>")
             .Append("</div>");

            b.Append("<table><thead><tr>")
             .Append("<th>SKU</th><th>PACKING</th><th>SHIP QTY</th><th>REC QTY</th><th>Expiry date</th><th>Nitrogen</th><th>DIFF ( +/-)</th>");
            for (int i = 1; i <= maxPallet; i++) b.Append("<th>PAL-").Append(i).Append("</th>");
            b.Append("<th>TOTAL</th></tr></thead><tbody>");

            decimal shipTotal = 0, recTotal = 0, diffTotal = 0;
            var palletTotals = new decimal[maxPallet];
            decimal palletGrandTotal = 0;

            foreach (var item in details.Items)
            {
                shipTotal += item.ExpectedQty;
                recTotal += item.TotalPhysicalQty;
                diffTotal += item.DifferenceQty;
                b.Append("<tr><td>").Append(E(item.SKU)).Append("</td>")
                 .Append("<td>").Append(E(item.ItemName)).Append("</td>")
                 .Append("<td class='right'>").Append(item.ExpectedQty).Append("</td>")
                 .Append("<td class='right'>").Append(item.TotalPhysicalQty).Append("</td>")
                 .Append("<td>").Append(E(item.ExpiryDate)).Append("</td>")
                 .Append("<td>").Append(E(item.Nitrogen)).Append("</td>")
                 .Append("<td class='right'>").Append(item.DifferenceQty > 0 ? "+" : "").Append(item.DifferenceQty).Append("</td>");

                decimal total = 0;
                bool hasPallet = false;
                for (int i = 1; i <= maxPallet; i++)
                {
                    var pallet = item.Pallets.FirstOrDefault(x => x.PalletNo == i);
                    if (pallet == null) b.Append("<td></td>");
                    else
                    {
                        b.Append("<td class='right'>").Append(pallet.Quantity).Append("</td>");
                        total += pallet.Quantity;
                        palletTotals[i - 1] += pallet.Quantity;
                        hasPallet = true;
                    }
                }
                if (hasPallet) palletGrandTotal += total;
                b.Append("<td class='right'>").Append(hasPallet ? total.ToString() : "").Append("</td></tr>");
            }

            b.Append("<tr class='total-row'><td colspan='2'><strong>ORDER TOTAL</strong></td>")
             .Append("<td class='right'><strong>").Append(shipTotal).Append("</strong></td>")
             .Append("<td class='right'><strong>").Append(recTotal).Append("</strong></td><td></td><td></td>")
             .Append("<td class='right'><strong>").Append(diffTotal > 0 ? "+" : "").Append(diffTotal).Append("</strong></td>");
            for (int i = 0; i < maxPallet; i++) b.Append("<td class='right'><strong>").Append(palletTotals[i] == 0 ? "" : palletTotals[i].ToString()).Append("</strong></td>");
            b.Append("<td class='right'><strong>").Append(palletGrandTotal == 0 ? "" : palletGrandTotal.ToString()).Append("</strong></td></tr>");

            b.Append("</tbody></table>")
             .Append("<div class='verify'><strong>Status: ").Append(E(details.Header.Status)).Append("</strong><br/>")
             .Append("Verified By: ").Append(E(details.Header.VerifiedBy)).Append("<br/>")
             .Append("Verified Date: ").Append(details.Header.VerifiedDate.HasValue ? details.Header.VerifiedDate.Value.ToString("yyyy-MM-dd HH:mm") : "").Append("<br/>")
             .Append("Verification Notes: ").Append(E(details.Header.VerificationNotes)).Append("</div>");

            ReportHtml.Text = b.ToString();
        }

        private static string E(string value)
        {
            return System.Web.HttpUtility.HtmlEncode(value ?? "");
        }
    }
}
