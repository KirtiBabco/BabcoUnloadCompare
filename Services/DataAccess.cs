using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using BabcoUnloadCompare.Web.Models;

namespace BabcoUnloadCompare.Web.Services
{
    public class DataAccess
    {
        private readonly string _appCs = GetRequiredConnectionString("UnloadCompareConnectionString");
        private readonly string _supportCs = GetRequiredConnectionString("BabcoSupportConnectionString");

        private static string GetRequiredConnectionString(string name)
        {
            return ConnectionStringResolver.GetRequired(name);
        }
        private static string CurrentUser { get { return AuthContext.CurrentUser; } }
        private SqlConnection Open() { var cn = new SqlConnection(_appCs); cn.Open(); return cn; }
        private static void Add(SqlCommand cmd, string name, object value) { cmd.Parameters.AddWithValue(name, value ?? DBNull.Value); }

        public List<PoSummary> SearchPO(string query)
        {
            return new BabcoOrderSource(_supportCs, _appCs).Search(query ?? "");
        }

        public PoLoadResult LoadPO(string po)
        {
            var result = new BabcoOrderSource(_supportCs, _appCs).Load(po);
            if (result != null) SyncPoSourceCache(result);
            return result;
        }

        private void SyncPoSourceCache(PoLoadResult result)
        {
            using (var cn = Open()) using (var tx = cn.BeginTransaction())
            {
                try
                {
                    using (var exists = new SqlCommand("SELECT CASE WHEN OBJECT_ID('dbo.UC_POHeaderSource','U') IS NOT NULL AND OBJECT_ID('dbo.UC_POItemSource','U') IS NOT NULL THEN 1 ELSE 0 END", cn, tx))
                    {
                        if (Convert.ToInt32(exists.ExecuteScalar()) != 1)
                            throw new InvalidOperationException("Unload Compare database tables are not installed. Run Database/01_Schema.sql and Database/02_StoredProcedures.sql against the Unload Compare application database.");
                    }

                    using (var cmd = new SqlCommand(@"MERGE dbo.UC_POHeaderSource AS T
USING (SELECT @PONumber PONumber) AS S ON T.PONumber=S.PONumber
WHEN MATCHED THEN UPDATE SET VendorName=@VendorName,ContainerNumber=@ContainerNumber,ReceivingDate=@ReceivingDate,IsActive=1
WHEN NOT MATCHED THEN INSERT(PONumber,VendorName,ContainerNumber,ReceivingDate,IsActive) VALUES(@PONumber,@VendorName,@ContainerNumber,@ReceivingDate,1);", cn, tx))
                    {
                        Add(cmd, "@PONumber", result.Header.PONumber); Add(cmd, "@VendorName", result.Header.VendorName); Add(cmd, "@ContainerNumber", result.Header.ContainerNumber); Add(cmd, "@ReceivingDate", result.Header.ReceivingDate);
                        cmd.ExecuteNonQuery();
                    }

                    using (var cmd = new SqlCommand("DELETE FROM dbo.UC_POItemSource WHERE PONumber=@PONumber", cn, tx))
                    {
                        Add(cmd, "@PONumber", result.Header.PONumber); cmd.ExecuteNonQuery();
                    }
                    foreach (var item in result.Items)
                    {
                        using (var cmd = new SqlCommand(@"INSERT dbo.UC_POItemSource(PONumber,SKU,ItemName,ExpectedQty,UOM,ExpectedPallets)
VALUES(@PONumber,@SKU,@ItemName,@ExpectedQty,@UOM,@ExpectedPallets);", cn, tx))
                        {
                            Add(cmd, "@PONumber", result.Header.PONumber); Add(cmd, "@SKU", item.SKU); Add(cmd, "@ItemName", item.ItemName); Add(cmd, "@ExpectedQty", item.ExpectedQty); Add(cmd, "@UOM", item.UOM); Add(cmd, "@ExpectedPallets", item.ExpectedPallets);
                            cmd.ExecuteNonQuery();
                        }
                    }
                    tx.Commit();
                }
                catch { tx.Rollback(); throw; }
            }
        }

        public int EnsureDraft(string po)
        {
            var live = LoadPO(po);
            if (live == null) throw new InvalidOperationException("PO does not exist in UOS_Order.");
            using (var cn = Open()) using (var cmd = new SqlCommand("usp_UC_EnsureDraft", cn)) { cmd.CommandType = CommandType.StoredProcedure; Add(cmd, "@PONumber", po); Add(cmd, "@UserName", CurrentUser); return Convert.ToInt32(cmd.ExecuteScalar()); }
        }

        public SaveResult SaveReceiving(ReceivingSaveRequest req)
        {
            if (req == null || string.IsNullOrWhiteSpace(req.PONumber)) throw new InvalidOperationException("PO Number is required.");
            if (req.Items == null || req.Items.Count == 0) throw new InvalidOperationException("At least one receiving item is required.");
            if (string.Equals(req.Status, "Ready for Verification", StringComparison.OrdinalIgnoreCase))
            {
                if (!req.UnloadDate.HasValue) throw new InvalidOperationException("Unload Date is required before verification.");
                if (string.IsNullOrWhiteSpace(req.UnloadBy1)) throw new InvalidOperationException("Unload By 1 is required before verification.");
            }
            using (var cn = Open()) using (var tx = cn.BeginTransaction())
            {
                try
                {
                    int receivingId;
                    using (var cmd = new SqlCommand("usp_UC_SaveReceivingHeader", cn, tx)) { cmd.CommandType = CommandType.StoredProcedure; Add(cmd, "@ReceivingId", req.ReceivingId); Add(cmd, "@PONumber", req.PONumber); Add(cmd, "@VendorName", req.VendorName); Add(cmd, "@ContainerNumber", req.ContainerNumber); Add(cmd, "@ReceivingDate", req.ReceivingDate ?? DateTime.Today); Add(cmd, "@UnloadDate", req.UnloadDate); Add(cmd, "@UnloadBy1", req.UnloadBy1); Add(cmd, "@UnloadBy2", req.UnloadBy2); Add(cmd, "@UnloadBy3", req.UnloadBy3); Add(cmd, "@Status", string.IsNullOrWhiteSpace(req.Status) ? "Draft" : req.Status); Add(cmd, "@Notes", req.Notes); Add(cmd, "@UserName", CurrentUser); receivingId = Convert.ToInt32(cmd.ExecuteScalar()); }
                    foreach (var item in req.Items)
                    {
                        if (string.IsNullOrWhiteSpace(item.SKU)) throw new InvalidOperationException("SKU is required on every row.");
                        int itemId;
                        using (var cmd = new SqlCommand("usp_UC_SaveReceivingItem", cn, tx))
                        {
                            cmd.CommandType = CommandType.StoredProcedure;
                            Add(cmd, "@ReceivingId", receivingId); Add(cmd, "@ReceivingItemId", item.ReceivingItemId); Add(cmd, "@SKU", item.SKU); Add(cmd, "@ItemName", item.ItemName); Add(cmd, "@ExpectedQty", item.ExpectedQty); Add(cmd, "@UOM", item.UOM); Add(cmd, "@ExpectedPallets", item.ExpectedPallets); Add(cmd, "@EntryMode", item.EntryMode ?? "Manual"); Add(cmd, "@ManualPhysicalQty", item.ManualPhysicalQty); Add(cmd, "@ExpiryDate", item.ExpiryDate); Add(cmd, "@Nitrogen", item.Nitrogen); Add(cmd, "@Notes", item.Notes); Add(cmd, "@UserName", CurrentUser);
                            itemId = Convert.ToInt32(cmd.ExecuteScalar());
                        }
                        using (var cmd = new SqlCommand("usp_UC_DeletePalletsForItem", cn, tx)) { cmd.CommandType = CommandType.StoredProcedure; Add(cmd, "@ReceivingItemId", itemId); cmd.ExecuteNonQuery(); }
                        if (string.Equals(item.EntryMode, "Pallet", StringComparison.OrdinalIgnoreCase) && item.Pallets != null)
                        {
                            foreach (var p in item.Pallets)
                            {
                                if (p.PalletNo < 1 || p.PalletNo > 5) throw new InvalidOperationException("Only PAL-1 through PAL-5 are allowed.");
                                if (p.Quantity < 0) throw new InvalidOperationException("Pallet quantity cannot be negative.");
                                using (var cmd = new SqlCommand("usp_UC_InsertPallet", cn, tx)) { cmd.CommandType = CommandType.StoredProcedure; Add(cmd, "@ReceivingItemId", itemId); Add(cmd, "@PalletNo", p.PalletNo); Add(cmd, "@Quantity", p.Quantity); Add(cmd, "@UserName", CurrentUser); cmd.ExecuteNonQuery(); }
                            }
                        }
                    }
                    using (var cmd = new SqlCommand("usp_UC_RecalculateReceiving", cn, tx)) { cmd.CommandType = CommandType.StoredProcedure; Add(cmd, "@ReceivingId", receivingId); Add(cmd, "@UserName", CurrentUser); cmd.ExecuteNonQuery(); }
                    tx.Commit(); return new SaveResult { ReceivingId = receivingId, Status = string.IsNullOrWhiteSpace(req.Status) ? "Draft" : req.Status };
                }
                catch { tx.Rollback(); throw; }
            }
        }

        public List<HistoryRow> GetHistory(HistoryFilter f)
        {
            f = f ?? new HistoryFilter(); var list = new List<HistoryRow>(); using (var cn = Open()) using (var cmd = new SqlCommand("usp_UC_GetHistory", cn)) { cmd.CommandType = CommandType.StoredProcedure; Add(cmd,"@PONumber",f.PONumber); Add(cmd,"@ContainerNumber",f.ContainerNumber); Add(cmd,"@Vendor",f.Vendor); Add(cmd,"@Status",f.Status); Add(cmd,"@User",f.User); Add(cmd,"@DateFrom",f.DateFrom); Add(cmd,"@DateTo",f.DateTo); using(var r=cmd.ExecuteReader()) while(r.Read()) list.Add(new HistoryRow { ReceivingId=Convert.ToInt32(r["ReceivingId"]), PONumber=r["PONumber"].ToString(), VendorName=r["VendorName"].ToString(), ContainerNumber=r["ContainerNumber"].ToString(), ReceivingDate=Convert.ToDateTime(r["ReceivingDate"]), UnloadDate=r["UnloadDate"]==DBNull.Value?(DateTime?)null:Convert.ToDateTime(r["UnloadDate"]), UnloadBy1=r["UnloadBy1"].ToString(), UnloadBy2=r["UnloadBy2"].ToString(), UnloadBy3=r["UnloadBy3"].ToString(), Status=r["Status"].ToString(), ItemCount=Convert.ToInt32(r["ItemCount"]), MismatchCount=Convert.ToInt32(r["MismatchCount"]), ModifiedBy=r["ModifiedBy"].ToString(), ModifiedDate=Convert.ToDateTime(r["ModifiedDate"]) }); } return list;
        }

        public ReceivingDetails GetDetails(int id)
        {
            var d = new ReceivingDetails { Items = new List<ReceivingItemDetail>(), Documents = new List<UploadedDocument>(), Audit = new List<AuditEntry>() };
            using (var cn=Open()) using(var cmd=new SqlCommand("usp_UC_GetReceivingDetails",cn)) { cmd.CommandType=CommandType.StoredProcedure; Add(cmd,"@ReceivingId",id); using(var r=cmd.ExecuteReader()) { if(!r.Read()) return null; d.Header=new ReceivingHeader { ReceivingId=id, PONumber=r["PONumber"].ToString(), VendorName=r["VendorName"].ToString(), ContainerNumber=r["ContainerNumber"].ToString(), ReceivingDate=Convert.ToDateTime(r["ReceivingDate"]), UnloadDate=r["UnloadDate"]==DBNull.Value?(DateTime?)null:Convert.ToDateTime(r["UnloadDate"]), UnloadBy1=r["UnloadBy1"].ToString(), UnloadBy2=r["UnloadBy2"].ToString(), UnloadBy3=r["UnloadBy3"].ToString(), Status=r["Status"].ToString(), Notes=r["Notes"].ToString(), CreatedBy=r["CreatedBy"].ToString(), CreatedDate=Convert.ToDateTime(r["CreatedDate"]), ModifiedBy=r["ModifiedBy"].ToString(), ModifiedDate=Convert.ToDateTime(r["ModifiedDate"]), VerifiedBy=r["VerifiedBy"].ToString(), VerifiedDate=r["VerifiedDate"]==DBNull.Value?(DateTime?)null:Convert.ToDateTime(r["VerifiedDate"]), VerificationNotes=r["VerificationNotes"].ToString() };
                if(r.NextResult()) while(r.Read()) d.Items.Add(new ReceivingItemDetail { ReceivingItemId=Convert.ToInt32(r["ReceivingItemId"]), SKU=r["SKU"].ToString(), ItemName=r["ItemName"].ToString(), ExpectedQty=Convert.ToDecimal(r["ExpectedQty"]), UOM=r["UOM"].ToString(), ExpectedPallets=r["ExpectedPallets"]==DBNull.Value?(int?)null:Convert.ToInt32(r["ExpectedPallets"]), EntryMode=r["EntryMode"].ToString(), ManualPhysicalQty=r["ManualPhysicalQty"]==DBNull.Value?(decimal?)null:Convert.ToDecimal(r["ManualPhysicalQty"]), ExpiryDate=r["ExpiryDate"].ToString(), Nitrogen=r["Nitrogen"].ToString(), TotalPhysicalQty=Convert.ToDecimal(r["TotalPhysicalQty"]), DifferenceQty=Convert.ToDecimal(r["DifferenceQty"]), CompareStatus=r["CompareStatus"].ToString(), Notes=r["Notes"].ToString() });
                if(r.NextResult()) while(r.Read()) { var item=d.Items.Find(x=>x.ReceivingItemId==Convert.ToInt32(r["ReceivingItemId"])); if(item!=null)item.Pallets.Add(new PalletInput{PalletId=Convert.ToInt32(r["PalletId"]),PalletNo=Convert.ToInt32(r["PalletNo"]),Quantity=Convert.ToDecimal(r["Quantity"])}); }
                if(r.NextResult()) while(r.Read()) d.Documents.Add(new UploadedDocument { DocumentId=Convert.ToInt32(r["DocumentId"]), OriginalFileName=r["OriginalFileName"].ToString(), ContentType=r["ContentType"].ToString(), FileSizeBytes=Convert.ToInt64(r["FileSizeBytes"]), ExtractionStatus=r["ExtractionStatus"].ToString(), UploadedBy=r["UploadedBy"].ToString(), UploadedDate=Convert.ToDateTime(r["UploadedDate"]) });
                if(r.NextResult()) while(r.Read()) d.Audit.Add(new AuditEntry { AuditId=Convert.ToInt32(r["AuditId"]), ActionType=r["ActionType"].ToString(), EntityType=r["EntityType"].ToString(), FieldName=r["FieldName"].ToString(), OldValue=r["OldValue"].ToString(), NewValue=r["NewValue"].ToString(), ChangedBy=r["ChangedBy"].ToString(), ChangedDate=Convert.ToDateTime(r["ChangedDate"]) });
            }} return d;
        }
        public void SetStatus(int id,string status,string notes)
        { using(var cn=Open()) using(var cmd=new SqlCommand("usp_UC_SetStatus",cn)){cmd.CommandType=CommandType.StoredProcedure;Add(cmd,"@ReceivingId",id);Add(cmd,"@Status",status);Add(cmd,"@Notes",notes);Add(cmd,"@UserName",CurrentUser);cmd.ExecuteNonQuery();} }
        public void Verify(int id,string notes)
        { using(var cn=Open()) using(var cmd=new SqlCommand("usp_UC_Verify",cn)){cmd.CommandType=CommandType.StoredProcedure;Add(cmd,"@ReceivingId",id);Add(cmd,"@Notes",notes);Add(cmd,"@UserName",CurrentUser);cmd.ExecuteNonQuery();} }
        public Dictionary<string,PoItemSource> GetPoItemMap(string po)
        { var result=LoadPO(po); var map=new Dictionary<string,PoItemSource>(StringComparer.OrdinalIgnoreCase); if(result!=null) foreach(var x in result.Items) map[x.SKU]=x; return map; }
        public void LogImport(int receivingId,string fileName,int totalRows,int matched,int unmatched,string status,string details)
        { using(var cn=Open()) using(var cmd=new SqlCommand("usp_UC_LogImport",cn)){cmd.CommandType=CommandType.StoredProcedure;Add(cmd,"@ReceivingId",receivingId);Add(cmd,"@FileName",fileName);Add(cmd,"@TotalRows",totalRows);Add(cmd,"@MatchedRows",matched);Add(cmd,"@UnmatchedRows",unmatched);Add(cmd,"@ImportStatus",status);Add(cmd,"@Details",details);Add(cmd,"@UserName",CurrentUser);cmd.ExecuteNonQuery();} }
        public int SaveDocument(int receivingId,string original,string stored,string type,long size)
        { using(var cn=Open()) using(var cmd=new SqlCommand("usp_UC_SaveDocument",cn)){cmd.CommandType=CommandType.StoredProcedure;Add(cmd,"@ReceivingId",receivingId);Add(cmd,"@OriginalFileName",original);Add(cmd,"@StoredFileName",stored);Add(cmd,"@ContentType",type);Add(cmd,"@FileSizeBytes",size);Add(cmd,"@UserName",CurrentUser);return Convert.ToInt32(cmd.ExecuteScalar());} }
        public Tuple<string,string,string> GetDocumentPath(int documentId)
        { using(var cn=Open()) using(var cmd=new SqlCommand("usp_UC_GetDocument",cn)){cmd.CommandType=CommandType.StoredProcedure;Add(cmd,"@DocumentId",documentId);using(var r=cmd.ExecuteReader()){if(!r.Read())return null;return Tuple.Create(r["StoredFileName"].ToString(),r["OriginalFileName"].ToString(),r["ContentType"].ToString());}} }
    }
}