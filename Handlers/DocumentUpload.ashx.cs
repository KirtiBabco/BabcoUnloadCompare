using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data.SqlClient;
using System.Globalization;
using System.IO;
using System.Net;
using System.Text;
using System.Web;
using System.Web.Script.Serialization;
using BabcoUnloadCompare.Web.Models;
using BabcoUnloadCompare.Web.Services;

namespace BabcoUnloadCompare.Web.Handlers
{
    public class DocumentUpload : IHttpHandler, System.Web.SessionState.IRequiresSessionState
    {
        private const string DefaultModel = "gpt-5.6-luna";
        public bool IsReusable { get { return false; } }

        public void ProcessRequest(HttpContext c)
        {
            c.Response.ContentType = "application/json";
            var js = new JavaScriptSerializer { MaxJsonLength = int.MaxValue };
            try
            {
                int receivingId;
                if (!int.TryParse(c.Request.Form["receivingId"], out receivingId) || receivingId <= 0)
                    throw new InvalidOperationException("Save the receiving draft before uploading a document.");

                var poNumber = (c.Request.Form["poNumber"] ?? "").Trim();
                if (string.IsNullOrWhiteSpace(poNumber))
                    throw new InvalidOperationException("PackingSlip is required before reading a receiving sheet.");

                var file = c.Request.Files["file"];
                UploadSecurity.Validate(file, UploadSecurity.DocumentExt);
                var safe = UploadSecurity.SafeFileName(file.FileName);
                var stored = Guid.NewGuid().ToString("N") + Path.GetExtension(safe).ToLowerInvariant();
                var root = c.Server.MapPath(ConfigurationManager.AppSettings["UnloadCompare.UploadRoot"]);
                var folder = Path.Combine(root, receivingId.ToString(CultureInfo.InvariantCulture));
                Directory.CreateDirectory(folder);
                var full = Path.GetFullPath(Path.Combine(folder, stored));
                if (!full.StartsWith(Path.GetFullPath(folder), StringComparison.OrdinalIgnoreCase))
                    throw new InvalidOperationException("Invalid upload path.");

                file.SaveAs(full);
                var dataAccess = new DataAccess();
                var documentId = dataAccess.SaveDocument(receivingId, safe, stored, file.ContentType, file.ContentLength);

                ImportPreview preview = null;
                var extractionStatus = "Uploaded - Review Needed";
                var extractionMessage = "Receiving sheet uploaded. AI scan reading is not configured; enter values manually or upload the filled Excel.";
                var apiKey = ReadSetting("OPENAI_API_KEY_DEVELOPMENT");
                if (string.IsNullOrWhiteSpace(apiKey)) apiKey = ReadSetting("OPENAI_API_KEY");

                if (!string.IsNullOrWhiteSpace(apiKey))
                {
                    try
                    {
                        var poItems = dataAccess.GetPoItemMap(poNumber);
                        if (poItems == null || poItems.Count == 0)
                            throw new InvalidOperationException("No PackingSlip items are available for scan matching.");

                        preview = ExtractPreview(File.ReadAllBytes(full), safe, file.ContentType, poItems, apiKey, js);
                        extractionStatus = preview.MatchedRows.Count > 0 ? "AI Preview Ready" : "AI Read - Review Needed";
                        extractionMessage = preview.MatchedRows.Count > 0
                            ? "Receiving sheet read. Review the extracted values before applying them."
                            : "Receiving sheet was read, but no rows were safe to auto-match. Review the unmatched rows.";
                        UpdateExtraction(documentId, extractionStatus, js.Serialize(preview));
                    }
                    catch (Exception extractionError)
                    {
                        extractionStatus = "AI Read - Review Needed";
                        extractionMessage = "File uploaded, but scan values could not be safely extracted: " + SafeMessage(extractionError.Message);
                        UpdateExtraction(documentId, extractionStatus, null);
                    }
                }
                else
                {
                    UpdateExtraction(documentId, extractionStatus, null);
                }

                c.Response.Write(js.Serialize(new
                {
                    IsSuccess = true,
                    Message = extractionMessage,
                    Data = new
                    {
                        DocumentId = documentId,
                        OriginalFileName = safe,
                        ExtractionStatus = extractionStatus,
                        Preview = preview
                    }
                }));
            }
            catch (Exception ex)
            {
                c.Response.StatusCode = 400;
                c.Response.Write(js.Serialize(new { IsSuccess = false, Message = ex.Message }));
            }
        }

        private static string ReadSetting(string name)
        {
            var value = Environment.GetEnvironmentVariable(name);
            if (string.IsNullOrWhiteSpace(value)) value = Environment.GetEnvironmentVariable("APPSETTING_" + name);
            if (string.IsNullOrWhiteSpace(value)) value = ConfigurationManager.AppSettings[name];
            return string.IsNullOrWhiteSpace(value) ? null : value.Trim();
        }

        private static ImportPreview ExtractPreview(byte[] bytes, string fileName, string contentType, Dictionary<string, PoItemSource> poItems, string apiKey, JavaScriptSerializer js)
        {
            var model = ReadSetting("UnloadCompare.DocumentAIModel");
            if (string.IsNullOrWhiteSpace(model)) model = ReadSetting("OPENAI_MODEL_DOCUMENT_EXTRACTION");
            if (string.IsNullOrWhiteSpace(model)) model = DefaultModel;

            var reference = new StringBuilder();
            reference.AppendLine("Read this completed warehouse receiving sheet for the selected PackingSlip.");
            reference.AppendLine("Extract ONLY values actually visible in the uploaded sheet. Never invent a quantity.");
            reference.AppendLine("Match rows to the selected PackingSlip by SKU. If uncertain, keep the visible SKU and leave uncertain values blank.");
            reference.AppendLine("Fields: SKU, SHIP QTY, REC QTY, Expiry date, Nitrogen, PAL-1, PAL-2, PAL-3, PAL-4, PAL-5.");
            reference.AppendLine("The application will independently validate every extracted row before it can be applied.");
            reference.AppendLine("Selected PackingSlip reference rows:");
            foreach (var pair in poItems)
                reference.AppendLine(pair.Key + " | SHIP QTY=" + pair.Value.ExpectedQty.ToString(CultureInfo.InvariantCulture) + " | " + (pair.Value.ItemName ?? ""));

            var inputContent = new List<object>();
            inputContent.Add(new { type = "input_text", text = reference.ToString() });
            var base64 = Convert.ToBase64String(bytes);
            var ext = Path.GetExtension(fileName ?? "").ToLowerInvariant();
            if (ext == ".pdf")
            {
                inputContent.Add(new { type = "input_file", filename = fileName, file_data = "data:application/pdf;base64," + base64 });
            }
            else
            {
                var mime = NormalizeImageContentType(contentType, ext);
                inputContent.Add(new { type = "input_image", image_url = "data:" + mime + ";base64," + base64, detail = "high" });
            }

            var rowProperties = new Dictionary<string, object>
            {
                { "sku", new { type = "string" } },
                { "shipQty", new { type = "string" } },
                { "recQty", new { type = "string" } },
                { "expiryDate", new { type = "string" } },
                { "nitrogen", new { type = "string" } },
                { "pal1", new { type = "string" } },
                { "pal2", new { type = "string" } },
                { "pal3", new { type = "string" } },
                { "pal4", new { type = "string" } },
                { "pal5", new { type = "string" } }
            };
            var schema = new
            {
                type = "object",
                properties = new Dictionary<string, object>
                {
                    { "rows", new { type = "array", items = new { type = "object", properties = rowProperties, required = new[] { "sku", "shipQty", "recQty", "expiryDate", "nitrogen", "pal1", "pal2", "pal3", "pal4", "pal5" }, additionalProperties = false } } }
                },
                required = new[] { "rows" },
                additionalProperties = false
            };
            var payload = new
            {
                model = model,
                store = false,
                reasoning = new { effort = "low" },
                input = new[] { new { role = "user", content = inputContent.ToArray() } },
                text = new { format = new { type = "json_schema", name = "unload_receiving_sheet", strict = true, schema = schema } }
            };

            var requestJson = js.Serialize(payload);
            var request = (HttpWebRequest)WebRequest.Create("https://api.openai.com/v1/responses");
            request.Method = "POST";
            request.ContentType = "application/json";
            request.Accept = "application/json";
            request.Headers[HttpRequestHeader.Authorization] = "Bearer " + apiKey;
            request.Timeout = 120000;
            request.ReadWriteTimeout = 120000;
            var requestBytes = Encoding.UTF8.GetBytes(requestJson);
            request.ContentLength = requestBytes.Length;
            using (var stream = request.GetRequestStream()) stream.Write(requestBytes, 0, requestBytes.Length);

            string responseJson;
            try
            {
                using (var response = (HttpWebResponse)request.GetResponse())
                using (var reader = new StreamReader(response.GetResponseStream())) responseJson = reader.ReadToEnd();
            }
            catch (WebException webEx)
            {
                var detail = "";
                if (webEx.Response != null)
                {
                    using (var reader = new StreamReader(webEx.Response.GetResponseStream())) detail = reader.ReadToEnd();
                }
                throw new InvalidOperationException("OpenAI scan extraction request failed. " + SafeMessage(detail));
            }

            var outputText = FindOutputText(js.DeserializeObject(responseJson));
            if (string.IsNullOrWhiteSpace(outputText)) throw new InvalidOperationException("OpenAI returned no structured extraction output.");
            var extracted = js.Deserialize<ScanExtraction>(outputText);
            if (extracted == null || extracted.rows == null) throw new InvalidOperationException("OpenAI extraction output did not contain rows.");
            return ValidateExtraction(fileName, extracted, poItems);
        }

        private static ImportPreview ValidateExtraction(string fileName, ScanExtraction extraction, Dictionary<string, PoItemSource> poItems)
        {
            var preview = new ImportPreview
            {
                FileName = fileName,
                MatchedRows = new List<ImportPreviewRow>(),
                UnmatchedRows = new List<ImportPreviewRow>(),
                Errors = new List<string>()
            };
            var rowNo = 1;
            foreach (var source in extraction.rows)
            {
                var sku = (source.sku ?? "").Trim();
                if (string.IsNullOrWhiteSpace(sku)) { rowNo++; continue; }
                var row = new ImportPreviewRow { RowNo = rowNo++, SKU = sku, ExpiryDate = (source.expiryDate ?? "").Trim(), Nitrogen = (source.nitrogen ?? "").Trim() };
                PoItemSource po;
                if (!poItems.TryGetValue(sku, out po))
                {
                    row.IsMatched = false; row.ValidationMessage = "SKU does not belong to selected PackingSlip"; preview.UnmatchedRows.Add(row); continue;
                }
                row.ItemName = po.ItemName;

                decimal ship;
                if (TryDecimal(source.shipQty, out ship) && ship != po.ExpectedQty)
                {
                    row.IsMatched = false; row.ValidationMessage = "Read SHIP QTY differs from selected PackingSlip"; preview.UnmatchedRows.Add(row); continue;
                }

                var palletValues = new[] { source.pal1, source.pal2, source.pal3, source.pal4, source.pal5 };
                decimal palletTotal = 0; var hasPallet = false; var badPallet = false;
                foreach (var value in palletValues)
                {
                    decimal parsed;
                    if (string.IsNullOrWhiteSpace(value)) { row.Pallets.Add(null); continue; }
                    if (!TryDecimal(value, out parsed) || parsed < 0) { row.Pallets.Add(null); badPallet = true; continue; }
                    row.Pallets.Add(parsed); palletTotal += parsed; hasPallet = true;
                }
                if (badPallet) { row.IsMatched = false; row.ValidationMessage = "One or more pallet quantities could not be read safely"; preview.UnmatchedRows.Add(row); continue; }

                decimal rec;
                var hasRec = TryDecimal(source.recQty, out rec);
                if (hasRec && rec < 0) { row.IsMatched = false; row.ValidationMessage = "Invalid REC QTY"; preview.UnmatchedRows.Add(row); continue; }
                if (hasRec && hasPallet && rec != palletTotal) { row.IsMatched = false; row.ValidationMessage = "REC QTY does not match pallet TOTAL"; preview.UnmatchedRows.Add(row); continue; }
                row.Quantity = hasRec ? (decimal?)rec : (hasPallet ? (decimal?)palletTotal : null);
                if (!row.Quantity.HasValue) { row.IsMatched = false; row.ValidationMessage = "REC QTY could not be read"; preview.UnmatchedRows.Add(row); continue; }

                row.IsMatched = true;
                row.ValidationMessage = "AI read + PackingSlip validated";
                preview.MatchedRows.Add(row);
            }
            return preview;
        }

        private static bool TryDecimal(string value, out decimal number)
        {
            number = 0;
            if (string.IsNullOrWhiteSpace(value)) return false;
            var clean = value.Trim().Replace(",", "");
            return decimal.TryParse(clean, NumberStyles.Any, CultureInfo.InvariantCulture, out number) || decimal.TryParse(clean, out number);
        }

        private static string NormalizeImageContentType(string contentType, string ext)
        {
            if (!string.IsNullOrWhiteSpace(contentType) && contentType.StartsWith("image/", StringComparison.OrdinalIgnoreCase)) return contentType;
            if (ext == ".png") return "image/png";
            if (ext == ".webp") return "image/webp";
            return "image/jpeg";
        }

        private static string FindOutputText(object root)
        {
            var dict = root as Dictionary<string, object>;
            if (dict == null || !dict.ContainsKey("output")) return null;
            var output = dict["output"] as object[];
            if (output == null) return null;
            foreach (var item in output)
            {
                var itemDict = item as Dictionary<string, object>;
                if (itemDict == null || !itemDict.ContainsKey("content")) continue;
                var content = itemDict["content"] as object[];
                if (content == null) continue;
                foreach (var part in content)
                {
                    var partDict = part as Dictionary<string, object>;
                    if (partDict == null) continue;
                    object typeValue; object textValue;
                    if (partDict.TryGetValue("type", out typeValue) && string.Equals(Convert.ToString(typeValue), "output_text", StringComparison.OrdinalIgnoreCase) && partDict.TryGetValue("text", out textValue))
                        return Convert.ToString(textValue);
                }
            }
            return null;
        }

        private static void UpdateExtraction(int documentId, string status, string extractionJson)
        {
            try
            {
                using (var cn = new SqlConnection(ConnectionStringResolver.GetRequired("UnloadCompareConnectionString")))
                using (var cmd = new SqlCommand("UPDATE dbo.UC_UploadedDocument SET ExtractionStatus=@Status, ExtractionJson=@Json WHERE DocumentId=@DocumentId", cn))
                {
                    cmd.Parameters.AddWithValue("@Status", status ?? "Pending Review");
                    cmd.Parameters.AddWithValue("@Json", string.IsNullOrWhiteSpace(extractionJson) ? (object)DBNull.Value : extractionJson);
                    cmd.Parameters.AddWithValue("@DocumentId", documentId);
                    cn.Open(); cmd.ExecuteNonQuery();
                }
            }
            catch { }
        }

        private static string SafeMessage(string message)
        {
            if (string.IsNullOrWhiteSpace(message)) return "Please review the file manually.";
            var text = message.Replace("\r", " ").Replace("\n", " ").Trim();
            if (text.Length > 300) text = text.Substring(0, 300) + "...";
            return text;
        }

        private sealed class ScanExtraction
        {
            public List<ScanExtractionRow> rows { get; set; }
        }
        private sealed class ScanExtractionRow
        {
            public string sku { get; set; }
            public string shipQty { get; set; }
            public string recQty { get; set; }
            public string expiryDate { get; set; }
            public string nitrogen { get; set; }
            public string pal1 { get; set; }
            public string pal2 { get; set; }
            public string pal3 { get; set; }
            public string pal4 { get; set; }
            public string pal5 { get; set; }
        }
    }
}
