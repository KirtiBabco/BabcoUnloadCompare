using System;
using System.Collections.Generic;
using System.Data;
using System.Globalization;
using System.IO;
using System.Linq;
using ExcelDataReader;
using BabcoUnloadCompare.Web.Models;

namespace BabcoUnloadCompare.Web.Services
{
    public class ExcelImportService
    {
        public ImportPreview Preview(Stream stream,string fileName,Dictionary<string,PoItemSource> poItems)
        {
            var p=new ImportPreview{FileName=fileName,MatchedRows=new List<ImportPreviewRow>(),UnmatchedRows=new List<ImportPreviewRow>(),Errors=new List<string>()};
            using(var reader=ExcelReaderFactory.CreateReader(stream))
            {
                var ds=reader.AsDataSet(new ExcelDataSetConfiguration{ConfigureDataTable=_=>new ExcelDataTableConfiguration{UseHeaderRow=true}});
                if(ds.Tables.Count==0){p.Errors.Add("The workbook contains no readable sheets.");return p;}
                var t=ds.Tables[0];
                int skuCol=FindCol(t,"sku","item","item id","itemid");
                int shipCol=FindCol(t,"ship qty","expected qty","order qty");
                int qtyCol=FindCol(t,"rec qty","received qty","physical qty","quantity","qty","unloaded qty");
                int nameCol=FindCol(t,"packing","item name","name","description");
                int expiryCol=FindCol(t,"expiry date","expiry","exp date");
                int nitrogenCol=FindCol(t,"nitrogen","n2");
                var palletCols=new List<int>();
                for(int n=1;n<=5;n++) palletCols.Add(FindCol(t,"pal-"+n,"pal "+n,"pallet "+n,"pallet "+n+" qty","p"+n));

                if(skuCol<0)p.Errors.Add("SKU column was not found.");
                if(shipCol<0)p.Errors.Add("SHIP QTY column was not found. Upload the Excel downloaded from this PO screen.");
                if(qtyCol<0 && palletCols.All(x=>x<0))p.Errors.Add("REC QTY or PAL-1/PAL-2/... quantity columns were not found.");
                if(p.Errors.Count>0)return p;

                for(int i=0;i<t.Rows.Count;i++)
                {
                    var sku=Convert.ToString(t.Rows[i][skuCol]).Trim(); if(string.IsNullOrWhiteSpace(sku))continue;
                    if(string.Equals(sku,"ORDER TOTAL",StringComparison.OrdinalIgnoreCase) || string.Equals(sku,"TOTAL",StringComparison.OrdinalIgnoreCase)) continue;
                    var row=new ImportPreviewRow{RowNo=i+2,SKU=sku,ItemName=nameCol>=0?Convert.ToString(t.Rows[i][nameCol]):"",ExpiryDate=expiryCol>=0?Convert.ToString(t.Rows[i][expiryCol]).Trim():"",Nitrogen=nitrogenCol>=0?Convert.ToString(t.Rows[i][nitrogenCol]).Trim():""};

                    PoItemSource po;
                    if(!poItems.TryGetValue(sku,out po))
                    {
                        row.IsMatched=false;row.ValidationMessage="SKU does not belong to selected PO";p.UnmatchedRows.Add(row);continue;
                    }
                    var shipRaw=Convert.ToString(t.Rows[i][shipCol]).Trim();
                    decimal shipQty;
                    if(!TryDecimal(shipRaw,out shipQty))
                    {
                        row.IsMatched=false;row.ValidationMessage="Invalid SHIP QTY";p.UnmatchedRows.Add(row);continue;
                    }
                    if(shipQty!=po.ExpectedQty)
                    {
                        row.IsMatched=false;row.ValidationMessage="SHIP QTY differs from selected PO";p.UnmatchedRows.Add(row);continue;
                    }

                    decimal? recQty=null;
                    if(qtyCol>=0)
                    {
                        var raw=Convert.ToString(t.Rows[i][qtyCol]).Trim();
                        if(!string.IsNullOrWhiteSpace(raw))
                        {
                            decimal parsed;
                            if(!TryDecimal(raw,out parsed) || parsed<0){row.ValidationMessage="Invalid REC QTY";row.IsMatched=false;p.UnmatchedRows.Add(row);continue;}
                            recQty=parsed;
                        }
                    }

                    decimal palletTotal=0; bool hasPallet=false; bool badPallet=false;
                    foreach(var col in palletCols)
                    {
                        if(col<0){row.Pallets.Add(null);continue;}
                        var raw=Convert.ToString(t.Rows[i][col]).Trim();
                        if(string.IsNullOrWhiteSpace(raw)){row.Pallets.Add(null);continue;}
                        decimal parsed;
                        if(!TryDecimal(raw,out parsed) || parsed<0){badPallet=true;row.Pallets.Add(null);continue;}
                        row.Pallets.Add(parsed); palletTotal+=parsed; hasPallet=true;
                    }
                    while(row.Pallets.Count>0 && row.Pallets[row.Pallets.Count-1]==null) row.Pallets.RemoveAt(row.Pallets.Count-1);
                    if(badPallet){row.ValidationMessage="Invalid pallet quantity";row.IsMatched=false;p.UnmatchedRows.Add(row);continue;}
                    if(recQty.HasValue && hasPallet && recQty.Value!=palletTotal){row.ValidationMessage="REC QTY does not match pallet TOTAL";row.IsMatched=false;p.UnmatchedRows.Add(row);continue;}
                    row.Quantity=recQty ?? (hasPallet?(decimal?)palletTotal:null);
                    if(!row.Quantity.HasValue){row.ValidationMessage="REC QTY is blank";row.IsMatched=false;p.UnmatchedRows.Add(row);continue;}

                    row.IsMatched=true;row.ItemName=po.ItemName;p.MatchedRows.Add(row);
                }
            }
            return p;
        }

        private static bool TryDecimal(string value,out decimal qty)
        {
            return decimal.TryParse(value,NumberStyles.Any,CultureInfo.InvariantCulture,out qty) || decimal.TryParse(value,out qty);
        }

        private static int FindCol(DataTable t,params string[] aliases)
        {
            for(int i=0;i<t.Columns.Count;i++)
            {
                var n=Normalize(t.Columns[i].ColumnName);
                foreach(var a in aliases) if(n==Normalize(a)) return i;
            }
            return -1;
        }
        private static string Normalize(string value)
        {
            return (value??"").Trim().ToLowerInvariant().Replace("_"," ").Replace("  "," ");
        }
    }
}
