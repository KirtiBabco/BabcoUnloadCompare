using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.IO.Compression;
using System.Security;
using System.Text;

namespace BabcoUnloadCompare.Web.Services
{
    public static class SimpleXlsxWriter
    {
        public sealed class Formula
        {
            public string Expression { get; private set; }
            public Formula(string expression) { Expression = expression ?? ""; }
        }

        public static Formula Fx(string expression) { return new Formula(expression); }

        private static string X(object value)
        {
            return SecurityElement.Escape(Convert.ToString(value) ?? "");
        }

        private static void Add(ZipArchive zip, string name, string text)
        {
            var entry = zip.CreateEntry(name, CompressionLevel.Optimal);
            using (var stream = entry.Open())
            using (var writer = new StreamWriter(stream, new UTF8Encoding(false)))
                writer.Write(text);
        }

        public static byte[] Write(List<List<object>> rows)
        {
            int rowCount = rows == null ? 0 : rows.Count;
            int colCount = 0;
            if (rows != null)
                foreach (var row in rows) if (row != null) colCount = Math.Max(colCount, row.Count);

            using (var ms = new MemoryStream())
            {
                using (var zip = new ZipArchive(ms, ZipArchiveMode.Create, true))
                {
                    Add(zip, "[Content_Types].xml",
                        "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
                        "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">" +
                        "<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>" +
                        "<Default Extension=\"xml\" ContentType=\"application/xml\"/>" +
                        "<Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>" +
                        "<Override PartName=\"/xl/worksheets/sheet1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>" +
                        "<Override PartName=\"/xl/styles.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml\"/>" +
                        "</Types>");

                    Add(zip, "_rels/.rels",
                        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
                        "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" +
                        "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"xl/workbook.xml\"/>" +
                        "</Relationships>");

                    Add(zip, "xl/workbook.xml",
                        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
                        "<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">" +
                        "<sheets><sheet name=\"Unload Compare\" sheetId=\"1\" r:id=\"rId1\"/></sheets><calcPr calcId=\"0\" fullCalcOnLoad=\"1\" forceFullCalc=\"1\"/></workbook>");

                    Add(zip, "xl/_rels/workbook.xml.rels",
                        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
                        "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" +
                        "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet1.xml\"/>" +
                        "<Relationship Id=\"rId2\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles\" Target=\"styles.xml\"/>" +
                        "</Relationships>");

                    Add(zip, "xl/styles.xml", StylesXml());

                    var sb = new StringBuilder();
                    sb.Append("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
                      .Append("<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">");

                    if (rowCount > 0 && colCount > 0)
                        sb.Append("<dimension ref=\"A1:").Append(ColName(colCount)).Append(rowCount).Append("\"/>");

                    sb.Append("<sheetViews><sheetView workbookViewId=\"0\"><pane ySplit=\"1\" topLeftCell=\"A2\" activePane=\"bottomLeft\" state=\"frozen\"/></sheetView></sheetViews>")
                      .Append("<sheetFormatPr defaultRowHeight=\"15\"/>")
                      .Append("<cols>");
                    for (int c = 1; c <= colCount; c++)
                    {
                        double width = c == 2 ? 55 : (c == 1 ? 14 : 12);
                        sb.Append("<col min=\"").Append(c).Append("\" max=\"").Append(c).Append("\" width=\"")
                          .Append(width.ToString(CultureInfo.InvariantCulture)).Append("\" customWidth=\"1\"/>");
                    }
                    sb.Append("</cols><sheetData>");

                    for (int r = 0; r < rowCount; r++)
                    {
                        int rn = r + 1;
                        var row = rows[r] ?? new List<object>();
                        sb.Append("<row r=\"").Append(rn).Append("\">");
                        for (int c = 0; c < row.Count; c++)
                        {
                            object value = row[c];
                            string cellRef = ColName(c + 1) + rn;
                            int style = r == 0 ? 1 : 0;
                            var formula = value as Formula;
                            if (formula != null)
                            {
                                sb.Append("<c r=\"").Append(cellRef).Append("\" s=\"").Append(style).Append("\"><f>")
                                  .Append(X(formula.Expression)).Append("</f></c>");
                            }
                            else if (IsNumber(value))
                            {
                                sb.Append("<c r=\"").Append(cellRef).Append("\" s=\"").Append(style).Append("\" t=\"n\"><v>")
                                  .Append(Convert.ToString(value, CultureInfo.InvariantCulture)).Append("</v></c>");
                            }
                            else
                            {
                                sb.Append("<c r=\"").Append(cellRef).Append("\" s=\"").Append(style).Append("\" t=\"inlineStr\"><is><t xml:space=\"preserve\">")
                                  .Append(X(value)).Append("</t></is></c>");
                            }
                        }
                        sb.Append("</row>");
                    }
                    sb.Append("</sheetData>");
                    if (rowCount > 0 && colCount > 0)
                        sb.Append("<autoFilter ref=\"A1:").Append(ColName(colCount)).Append(rowCount).Append("\"/>");
                    sb.Append("<pageMargins left=\"0.25\" right=\"0.25\" top=\"0.5\" bottom=\"0.5\" header=\"0.3\" footer=\"0.3\"/>")
                      .Append("<pageSetup orientation=\"landscape\" fitToWidth=\"1\" fitToHeight=\"0\"/>")
                      .Append("</worksheet>");
                    Add(zip, "xl/worksheets/sheet1.xml", sb.ToString());
                }
                return ms.ToArray();
            }
        }

        private static bool IsNumber(object value)
        {
            return value is decimal || value is int || value is long || value is double || value is float || value is short || value is byte;
        }

        private static string ColName(int index)
        {
            var sb = new StringBuilder();
            while (index > 0)
            {
                index--;
                sb.Insert(0, (char)('A' + (index % 26)));
                index /= 26;
            }
            return sb.ToString();
        }

        private static string StylesXml()
        {
            return "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
                   "<styleSheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">" +
                   "<fonts count=\"2\"><font><sz val=\"10\"/><name val=\"Segoe UI\"/></font><font><b/><color rgb=\"FFFFFFFF\"/><sz val=\"10\"/><name val=\"Segoe UI\"/></font></fonts>" +
                   "<fills count=\"3\"><fill><patternFill patternType=\"none\"/></fill><fill><patternFill patternType=\"gray125\"/></fill><fill><patternFill patternType=\"solid\"><fgColor rgb=\"FF7F1D2D\"/><bgColor indexed=\"64\"/></patternFill></fill></fills>" +
                   "<borders count=\"1\"><border><left/><right/><top/><bottom/><diagonal/></border></borders>" +
                   "<cellStyleXfs count=\"1\"><xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\"/></cellStyleXfs>" +
                   "<cellXfs count=\"2\"><xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\" xfId=\"0\"/><xf numFmtId=\"0\" fontId=\"1\" fillId=\"2\" borderId=\"0\" xfId=\"0\" applyFont=\"1\" applyFill=\"1\" applyAlignment=\"1\"><alignment horizontal=\"center\" vertical=\"center\" wrapText=\"1\"/></xf></cellXfs>" +
                   "<cellStyles count=\"1\"><cellStyle name=\"Normal\" xfId=\"0\" builtinId=\"0\"/></cellStyles>" +
                   "</styleSheet>";
        }
    }
}
