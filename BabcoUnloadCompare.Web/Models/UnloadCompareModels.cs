using System;
using System.Collections.Generic;

namespace BabcoUnloadCompare.Web.Models
{
    public class ApiResult<T> { public bool IsSuccess { get; set; } public string Message { get; set; } public T Data { get; set; } }
    public class PoSummary { public string PONumber { get; set; } public string VendorName { get; set; } public string ContainerNumber { get; set; } public DateTime? ReceivingDate { get; set; } public int ItemCount { get; set; } }
    public class PoItemSource { public string SKU { get; set; } public string ItemName { get; set; } public decimal ExpectedQty { get; set; } public string UOM { get; set; } public int? ExpectedPallets { get; set; } }
    public class PoLoadResult { public PoSummary Header { get; set; } public List<PoItemSource> Items { get; set; } public int? ExistingReceivingId { get; set; } }
    public class PalletInput { public int? PalletId { get; set; } public int PalletNo { get; set; } public decimal Quantity { get; set; } }
    public class ReceivingItemInput
    {
        public int? ReceivingItemId { get; set; }
        public string SKU { get; set; }
        public string ItemName { get; set; }
        public decimal ExpectedQty { get; set; }
        public string UOM { get; set; }
        public int? ExpectedPallets { get; set; }
        public string EntryMode { get; set; }
        public decimal? ManualPhysicalQty { get; set; }
        public string ExpiryDate { get; set; }
        public string Nitrogen { get; set; }
        public string Notes { get; set; }
        public List<PalletInput> Pallets { get; set; }
    }
    public class ReceivingSaveRequest { public int? ReceivingId { get; set; } public string PONumber { get; set; } public string VendorName { get; set; } public string ContainerNumber { get; set; } public DateTime? ReceivingDate { get; set; } public DateTime? UnloadDate { get; set; } public string UnloadBy1 { get; set; } public string UnloadBy2 { get; set; } public string UnloadBy3 { get; set; } public string Status { get; set; } public string Notes { get; set; } public List<ReceivingItemInput> Items { get; set; } }
    public class SaveResult { public int ReceivingId { get; set; } public string Status { get; set; } }
    public class ReceivingHeader { public int ReceivingId { get; set; } public string PONumber { get; set; } public string VendorName { get; set; } public string ContainerNumber { get; set; } public DateTime ReceivingDate { get; set; } public DateTime? UnloadDate { get; set; } public string UnloadBy1 { get; set; } public string UnloadBy2 { get; set; } public string UnloadBy3 { get; set; } public string Status { get; set; } public string Notes { get; set; } public string CreatedBy { get; set; } public DateTime CreatedDate { get; set; } public string ModifiedBy { get; set; } public DateTime ModifiedDate { get; set; } public string VerifiedBy { get; set; } public DateTime? VerifiedDate { get; set; } public string VerificationNotes { get; set; } }
    public class ReceivingItemDetail
    {
        public int ReceivingItemId { get; set; }
        public string SKU { get; set; }
        public string ItemName { get; set; }
        public decimal ExpectedQty { get; set; }
        public string UOM { get; set; }
        public int? ExpectedPallets { get; set; }
        public string EntryMode { get; set; }
        public decimal? ManualPhysicalQty { get; set; }
        public string ExpiryDate { get; set; }
        public string Nitrogen { get; set; }
        public decimal TotalPhysicalQty { get; set; }
        public decimal DifferenceQty { get; set; }
        public string CompareStatus { get; set; }
        public string Notes { get; set; }
        public List<PalletInput> Pallets { get; set; } = new List<PalletInput>();
    }
    public class UploadedDocument { public int DocumentId { get; set; } public string OriginalFileName { get; set; } public string ContentType { get; set; } public long FileSizeBytes { get; set; } public string ExtractionStatus { get; set; } public string UploadedBy { get; set; } public DateTime UploadedDate { get; set; } }
    public class AuditEntry { public int AuditId { get; set; } public string ActionType { get; set; } public string EntityType { get; set; } public string FieldName { get; set; } public string OldValue { get; set; } public string NewValue { get; set; } public string ChangedBy { get; set; } public DateTime ChangedDate { get; set; } }
    public class ReceivingDetails { public ReceivingHeader Header { get; set; } public List<ReceivingItemDetail> Items { get; set; } public List<UploadedDocument> Documents { get; set; } public List<AuditEntry> Audit { get; set; } }
    public class HistoryFilter { public string PONumber { get; set; } public string ContainerNumber { get; set; } public string Vendor { get; set; } public string Status { get; set; } public string User { get; set; } public DateTime? DateFrom { get; set; } public DateTime? DateTo { get; set; } }
    public class HistoryRow { public int ReceivingId { get; set; } public string PONumber { get; set; } public string VendorName { get; set; } public string ContainerNumber { get; set; } public DateTime ReceivingDate { get; set; } public DateTime? UnloadDate { get; set; } public string UnloadBy1 { get; set; } public string UnloadBy2 { get; set; } public string UnloadBy3 { get; set; } public string Status { get; set; } public int ItemCount { get; set; } public int MismatchCount { get; set; } public string ModifiedBy { get; set; } public DateTime ModifiedDate { get; set; } }
    public class ImportPreviewRow
    {
        public int RowNo { get; set; }
        public string SKU { get; set; }
        public string ItemName { get; set; }
        public decimal? Quantity { get; set; }
        public string ExpiryDate { get; set; }
        public string Nitrogen { get; set; }
        public List<decimal?> Pallets { get; set; } = new List<decimal?>();
        public bool IsMatched { get; set; }
        public string ValidationMessage { get; set; }
    }
    public class ImportPreview { public string FileName { get; set; } public List<ImportPreviewRow> MatchedRows { get; set; } public List<ImportPreviewRow> UnmatchedRows { get; set; } public List<string> Errors { get; set; } }
}
