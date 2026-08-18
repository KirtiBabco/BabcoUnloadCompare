# Babco Foods - Unload Compare v1.2.0

ASP.NET Web Forms internal receiving module for PO unload comparison, pallet counts, verification, Excel import/export, receiving-sheet upload, print output, history, and audit trail.

## Current v1.2.0 highlights

- Replaced the top menu with a professional fixed **left sidebar** on desktop and an off-canvas left drawer on tablet/mobile.
- Removed the separate blank/default Excel format download. The Excel workflow is now **Download selected PO records → fill the same workbook → Upload Filled Excel → preview/apply**.
- Download Excel auto-saves the current draft so already-entered receiving data is included. Blank receiving rows remain `Pending` in SQL/history instead of becoming fake `Short` mismatches.
- Upload validates both `SKU` and `SHIP QTY` against the currently selected live PO before data can be applied.

- Fixed IIS Express `HTTP 403.14 - Forbidden` at the site root by adding `Default.aspx`, configuring `Web.config` default documents, and aligning Visual Studio startup settings.

- Fixed recurring `CS0234` / `CS0246` errors for `System.Web.Services`, `WebMethod`, and `WebMethodAttribute` by adding the required framework assembly reference `<Reference Include="System.Web.Services" />` to `BabcoUnloadCompare.Web.csproj`.
- Added a mandatory WebForms reference audit: if source uses `System.Web.Services` / `[WebMethod]`, the project must reference `System.Web.Services`; if source uses `System.Web.Script.*`, the project must reference `System.Web.Extensions`.
- Preserved the v1.1.1 multiline SQL-string (`CS1010`) repair in `Services/BabcoOrderSource.cs`.
- Fixed the Visual Studio solution definition that could show `Solution 'BabcoUnloadCompare' (0 of 1 project)` and `BabcoUnloadCompare.Web (unloaded)`.
- The `.sln` now uses the standard C# project type GUID; the `.csproj` retains the ASP.NET Web Application + C# `ProjectTypeGuids` and WebApplication targets.
- Database source changed to live database `Babco`.
- Live order source is `UOS_Order` + `UOS_OrderDetail` + `Item`.
- Order-wise SKU comes from `UOS_OrderDetail.SKU`. PACKING prefers `Item.ItemName` matched by SKU, then falls back to `UOS_OrderDetail.ItemName`.
- Live UOS mapping is now zero-config for columns. `UOS_OrderDetail.SKU`, `UOS_OrderDetail.Qty`, and `UOS_OrderDetail.ItemName` are used directly when present; `Item` is only optional SKU-based enrichment for PACKING/UOM. Missing optional source fields are returned blank.
- Added Expiry date and Nitrogen to receiving-item storage/import/display/export.
- Excel export and print use the requested core sequence:
  `SKU | PACKING | SHIP QTY | REC QTY | Expiry date | Nitrogen | DIFF ( +/-) | PAL-1 ... PAL-5 | TOTAL`.
- The current receiving layout uses exactly PAL-1 through PAL-5.

## Visual Studio: if the project was previously unloaded

Use a fresh extraction of this ZIP. Do not copy the new files over the old `.vs` cache.

1. Close Visual Studio.
2. Extract the new ZIP to a fresh folder.
3. Delete `.vs`, `bin`, and `obj` if they exist from an older copy.
4. Open `BabcoUnloadCompare.sln`.
5. If the project still appears unloaded, right-click `BabcoUnloadCompare.Web` and choose **Reload Project**.
6. If Visual Studio reports an unsupported project type, open Visual Studio Installer and install/repair **ASP.NET and web development** plus the **.NET Framework 4.7.2 targeting pack/developer pack**.
7. Restore NuGet packages.
8. Set `BabcoUnloadCompare.Web` as Startup Project.
9. `Default.aspx` is the configured Start Page and redirects to `UnloadCompare.aspx`; no manual Start Page change should be required.
10. Clean Solution, Rebuild Solution, then press F5.

The solution/project fix is also documented in `Docs/Technical-Master-Guidelines-Updated.md`.


### If Visual Studio shows `System.Web.Services` / `WebMethod` errors

Do not add/remove `using` directives as a workaround. The project must contain this framework reference:

```xml
<Reference Include="System.Web.Services" />
```

Then close Visual Studio, delete `.vs`, `bin`, and `obj`, reopen the solution, restore packages, and **Rebuild Solution**. If the reference still cannot resolve, install/repair the **.NET Framework 4.7.2 targeting/developer pack** and the **ASP.NET and web development** workload.

## Database connection

`BabcoUnloadCompare.Web/Web.config` contains the requested `ConnectionString` entry for database `Babco`.

For security, keep the live password in Web.config/protected configuration and do not copy it into documentation or source comments.

### Live source tables

- `dbo.UOS_Order` - order/header
- `dbo.UOS_OrderDetail` - child/detail
- `dbo.Item` - item master
- `UOS_OrderDetail.SKU` - order-wise SKU source
- `UOS_OrderDetail.Qty` - SHIP QTY source
- `UOS_OrderDetail.ItemName` - PACKING fallback
- `Item.SKU` / `Item.ItemName` - optional PACKING enrichment by SKU

No per-column `BabcoOrder.*` Web.config settings are required. The application reads the live schema and uses the following fixed business mapping:

- Order link: `UOS_Order.OrderId` / matching `UOS_OrderDetail.OrderId` when available.
- SKU: `UOS_OrderDetail.SKU`.
- SHIP QTY: `SUM(UOS_OrderDetail.Qty)` grouped by selected order + SKU.
- PACKING: `Item.ItemName` by SKU when available, otherwise `UOS_OrderDetail.ItemName`, otherwise blank.
- UOM/Vendor/Container/Receiving Date: auto-detected only when present; otherwise blank.
- REC QTY, Expiry date, Nitrogen, PAL-1+ and TOTAL are receiving-entry fields and start blank.

`SKU` is the logical item key inside an order. The internal cache already enforces `UNIQUE(PONumber, SKU)` and receiving rows enforce `UNIQUE(ReceivingId, SKU)`, so repeated detail rows for the same SKU are safely aggregated instead of duplicated.

Only genuinely critical missing source structure (missing `UOS_Order`, `UOS_OrderDetail`, order link, SKU, or Qty) blocks loading; optional columns never require manual configuration.

## Database installation

Run against the existing `Babco` database in this order:

1. `Database/01_Schema.sql`
2. `Database/02_StoredProcedures.sql`
3. `Database/04_SourceMapping_Diagnostics.sql` - diagnostic only, recommended before first test
4. `Database/05_Connection_Quick_Test.sql` - diagnostic only

`Database/03_SampleData.sql` intentionally does not create fake orders; the application uses the live UOS tables.

The new `UC_*` objects are additive. `UC_POHeaderSource` / `UC_POItemSource` are internal validation/cache tables synchronized from the selected live UOS PO; the live UOS tables remain the source of truth.

## Excel download / fill / upload workflow

There is no separate blank/default-format download. After a PO is loaded, click **Download Excel**. The downloaded workbook already contains the selected PO records in this exact column order:

`SKU, PACKING, SHIP QTY, REC QTY, Expiry date, Nitrogen, DIFF ( +/-), PAL-1, PAL-2, PAL-3, PAL-4, PAL-5, TOTAL`

Warehouse flow:

1. Search/load the PO.
2. Click **Download Excel**. The application saves the current receiving draft and downloads the PO rows as `UnloadCompare_<PO>_FillAndUpload.xlsx`.
3. In that same workbook, fill `REC QTY` directly **or** fill `PAL-1` through `PAL-5`; optionally fill Expiry date and Nitrogen.
   - `TOTAL` is formula-driven from PAL-1..PAL-5.
   - `DIFF` recalculates from REC QTY, or from pallet TOTAL when REC QTY is blank.
4. Do not change `SKU` or `SHIP QTY`.
5. Return to the same PO and click **Upload Filled Excel**.
6. Review the import preview. SKU must belong to the selected PO and SHIP QTY must still match the live selected-PO quantity.
7. Apply matched rows, review the grid, then Save / Ready to Verify.

If both REC QTY and pallet values are supplied, import requires REC QTY to equal the pallet total. Unmatched or invalid rows remain visible in the preview and are never silently discarded.

## Main files

- `BabcoUnloadCompare.sln`
- `BabcoUnloadCompare.Web/BabcoUnloadCompare.Web.csproj`
- `BabcoUnloadCompare.Web/UnloadCompare.aspx`
- `BabcoUnloadCompare.Web/UnloadCompareHistory.aspx`
- `BabcoUnloadCompare.Web/UnloadCompareDetails.aspx`
- `BabcoUnloadCompare.Web/UnloadComparePrint.aspx`
- `BabcoUnloadCompare.Web/Services/BabcoOrderSource.cs`
- `BabcoUnloadCompare.Web/Services/DataAccess.cs`
- `BabcoUnloadCompare.Web/Handlers/ExcelImport.ashx`
- `BabcoUnloadCompare.Web/Handlers/ExcelExport.ashx`
- `Database/*.sql`
- `Docs/Technical-Master-Guidelines-Updated.md`

## Runtime validation checklist

After the project loads in Visual Studio:

1. Confirm connection to `Babco`.
2. Optional: run `04_SourceMapping_Diagnostics.sql` for read-only schema visibility; no Web.config mapping is required.
3. Search a real PO from `UOS_Order`.
4. Confirm detail lines are grouped order-wise by `UOS_OrderDetail.SKU`; PACKING should come from `Item.ItemName` by SKU when available, otherwise `UOS_OrderDetail.ItemName`.
5. Confirm SHIP QTY matches the live order-detail quantity field.
6. Enter REC QTY and confirm DIFF updates.
7. Enter PAL-1 through PAL-5 and confirm TOTAL/REC comparison.
8. Save/reopen a draft.
9. Click Download Excel and confirm the selected PO records are present.
10. Fill REC QTY or PAL-1..PAL-5 in the downloaded workbook and upload that same workbook.
11. Confirm SKU and SHIP QTY validation plus matched/unmatched preview rows.
12. Save, verify, download Excel, and print the receiving report.
13. Check Build Output - not only Error List.



## v1.2.0 Left sidebar navigation

- Desktop navigation is a fixed left sidebar instead of a top menu.
- Main content uses the remaining full browser width.
- Current page is highlighted automatically.
- On tablet/mobile the same left menu becomes an off-canvas drawer opened from a compact menu button; it is not converted back to a permanent top navigation bar.
- Unload Compare and Receiving History remain the primary navigation destinations.

## IIS Express HTTP 403.14 - root URL/default document fix

If F5 opens `http://localhost:<port>/` and IIS shows **HTTP Error 403.14 - Forbidden / The Web server is configured to not list the contents of this directory**, do **not** enable directory browsing. That error means IIS reached the Web Application correctly but no default document was resolved for `/`.

Version 1.1.4 fixes this in three layers:

1. `Default.aspx` is included as the physical application entry page.
2. `Web.config` defines `Default.aspx` first under `system.webServer/defaultDocument`, with `UnloadCompare.aspx` as a fallback.
3. `BabcoUnloadCompare.Web.csproj` uses `StartAction=SpecificPage` and `StartPageUrl=Default.aspx`.

`Default.aspx` immediately transfers the browser to `~/UnloadCompare.aspx`, so opening either the root URL or the configured Visual Studio start page reaches the working Unload Compare screen.

After replacing an older package, close Visual Studio, delete `.vs`, `bin`, and `obj`, reopen the solution, set `BabcoUnloadCompare.Web` as Startup Project, Clean + Rebuild, and press F5. If a cached IIS Express profile still opens `/`, the new default-document rule handles it.


## v1.1.8 Compact Professional Receiving UI

- Main receiving grid is full-width and optimized for warehouse desktop/tablet use.
- Pallet entry is intentionally limited to **PAL-1 through PAL-5**. There is no PAL-6 / More Pallets UI.
- The grid uses compact row heights and column widths so more rows fit on one screen.
- Sticky SKU/packing context is preserved on desktop; mobile uses controlled horizontal scrolling.
- Default pagination is **15 rows** with 10 / 15 / 25 / 50 page-size choices.
- A sticky **ORDER TOTAL** footer shows SHIP QTY, entered REC QTY, PAL-1..PAL-5 totals, pallet TOTAL, and DIFF when all items have received quantities.
- Excel import accepts PAL-1..PAL-5 only; default format, export, details and print use the same five-pallet format.


## v1.2.0 Receiving Header Update

Added editable **Container Number**, **Unload Date**, **Unload By 1**, **Unload By 2**, and **Unload By 3**. Unload Date and Unload By 1 are required only when moving to **Ready for Verification**; Container Number remains optional for non-container receipts; drafts can still be saved incomplete. These fields persist in `UC_ReceivingHeader`, appear in Details, History, Print, and Audit.

### Two database connection strings

- `UnloadCompareConnectionString`: application-owned `UC_*` tables. Point this to the new Azure/application database.
- `BabcoSupportConnectionString`: read-only/supporting Babco source tables `UOS_Order`, `UOS_OrderDetail`, and `Item`. Change this independently.
- `ConnectionString`: backward-compatible fallback only.

### Recommended next production points (not forced into this release)

1. **Dock / Door Number** and **Unload Start / End Time** for warehouse productivity tracking.
2. **Container Seal Number** plus optional seal photo before unloading.
3. **Damage / Short / Over reason code** mandatory for mismatched rows before verification.
4. **Supervisor / verifier separation** so an unloader cannot verify the same receiving record.
5. **Autosave / dirty-state warning** to avoid losing warehouse entries on refresh or tablet sleep.
6. **Completed-record lock** with explicit admin reopen action and audit reason.
7. **Document retention / Azure Blob storage** for receiving sheets instead of local App_Data in production.
8. **Health/diagnostic page** showing App DB and Babco support DB connectivity separately without exposing secrets.
9. **Role permissions** for Warehouse, Verifier, Manager, and Admin.
10. **Operational monitoring** for failed Excel imports, DB timeouts, upload errors, and deployment health.
