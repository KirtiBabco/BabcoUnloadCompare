# Requirements Traceability - v1.2.0

| Requirement | Implementation |
|---|---|
| Visual Studio project must load from `.sln` | Correct C# project type GUID in `BabcoUnloadCompare.sln`; Web Application + C# flavors remain in `.csproj` |
| Database `Babco` | `Web.config` `ConnectionString`; SQL scripts use `USE [Babco]` |
| Orders from `UOS_Order` | `Services/BabcoOrderSource.cs` |
| Order child rows from `UOS_OrderDetail` | `Services/BabcoOrderSource.cs` |
| SKU/name from `Item` | Live join using configured/auto-mapped Item key; `Item.SKU` and `Item.ItemName` |
| Unknown UOS column names must not be guessed | Zero-config live schema mapping; order-wise `UOS_OrderDetail.SKU` + `Qty`; optional fields blank; `04_SourceMapping_Diagnostics.sql` read-only troubleshooting only |
| Default receiving format | Main grid uses SKU, PACKING, SHIP QTY, REC QTY, Expiry date, Nitrogen, DIFF, PAL-1..PAL-5, TOTAL as core sequence |
| Five pallet columns | Main grid/import/export/print use exactly PAL-1..PAL-5 |
| Expiry/Nitrogen saved | `UC_ReceivingItem.ExpiryDate`, `Nitrogen`; model/data/stored-proc/UI wiring |
| Excel download/fill/upload | `ExcelExport.ashx` downloads selected PO records; the same workbook is filled and uploaded through `ExcelImport.ashx` |
| Excel record download | `Handlers/ExcelExport.ashx` with PO records and requested core column order; no separate blank template |
| `.xls` / `.xlsx` upload | `Handlers/ExcelImport.ashx` + ExcelDataReader |
| Import preview / unmatched SKU | Preview modal; unmatched/error rows remain visible |
| REC vs pallet validation | Import rejects rows where supplied REC QTY differs from pallet TOTAL |
| PDF/JPG/PNG receiving sheet | `DocumentUpload.ashx`; original file stored under `App_Data` |
| OCR/AI-ready, human verification | `ExtractionStatus` + `ExtractionJson`; no automatic finalization |
| Difference / Matched / Short / Over | Client calculation plus SQL recalculation |
| Draft to Completed workflow | Header status + verification/complete transition checks |
| Verification metadata | Header fields + `UC_Verification` |
| Print report | `UnloadComparePrint.aspx` with requested core columns |
| Receiving history | `UnloadCompareHistory.aspx` |
| Audit trail | `UC_AuditLog` + detail page |
| Mobile/tablet-friendly | Responsive CSS and horizontally scrollable wide receiving grid |

| Compact full-screen receiving UI | Full-width page, compact header/summary/toolbar, five pallets, pagination, sticky order-total footer, responsive mobile/tablet horizontal grid |

| Left navigation | Fixed desktop sidebar in `Site.Master`; responsive off-canvas left drawer on tablet/mobile |
| Excel stale/wrong-file protection | Import validates both SKU membership and SHIP QTY against the selected live PO |


### v1.2.0 additions
- Container Number: editable receiving header, persisted/audited, details/history/print.
- Unload Date: receiving header, persisted/audited, details/history/print.
- Unload By 1/2/3: receiving team fields, persisted/audited, details/history/print.
- DB boundary: UC_* application DB is separate from Babco UOS/Item support source DB.
