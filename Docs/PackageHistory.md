# Package History

| Version | Date | Status | Notes |
|---|---|---|---|
| 1.0.0 | 2026-08-13 | Superseded | Initial Unload Compare delivery. Visual Studio solution could show project unloaded on the reported machine. |
| 1.1.0 | 2026-08-14 | Superseded | Corrected `.sln` project type, live `Babco` / UOS integration, requested default receiving format, Expiry/Nitrogen, default Excel template, and Excel export. |

| 1.1.1 | 2026-08-14 | Superseded | Fixed `CS1010 Newline in constant` in multiline SQL string handling. |
| 1.1.2 | 2026-08-14 | Superseded | Added missing `System.Web.Services` framework reference; fixes `CS0234` and `CS0246` WebMethod/WebMethodAttribute errors; strengthened reference validation. |

| 1.1.3 | 2026-08-14 | Superseded | Fixed IIS Express HTTP 403.14 at root URL by adding Default.aspx, Web.config defaultDocument configuration, and explicit Visual Studio StartAction/StartPageUrl; added permanent validation/documentation rule. |

| 1.1.4 | 2026-08-14 | Superseded | Removed per-column Web.config mapping, fixed UOS_OrderDetail SKU/Qty mapping, made Item enrichment optional by SKU, grouped detail by order+SKU, and made missing optional fields blank. |

## v1.1.7 - Positive quantity items only
- PO search ItemCount now counts only SKU groups where `SUM(UOS_OrderDetail.Qty) > 0`.
- PO item loading now excludes SKU groups whose summed ship quantity is zero or negative.
- NULL quantity is treated as zero.
- Duplicate OrderId+SKU detail lines are still combined before the positive-quantity filter is applied.


## v1.1.8 - Compact professional five-pallet receiving grid
- PAL-1 through PAL-5 only across UI, Excel import/export/default format, details and print.
- Removed More Pallets / dynamic pallet UI.
- Full-width compact receiving layout with reduced vertical whitespace.
- Viewport-height grid, dense rows, sticky context columns, responsive mobile/tablet behavior.
- Added 10/15/25/50 pagination with 15 rows default.
- Added complete-order sticky ORDER TOTAL footer and totals in Excel/print.
| 1.1.9 | 2026-08-14 | Current | Replaced top navigation with responsive left sidebar; removed separate default-format download; changed Excel flow to record-filled download → fill same workbook → upload/preview; added SKU + SHIP QTY round-trip validation. |


## v1.2.0
- Added Container Number, Unload Date, Unload By 1/2/3 end-to-end.
- Added Ready-for-Verification validation for Container, Unload Date, Unload By 1.
- Split application database and Babco supporting source database connection strings.
- Added header audit, history/details/print coverage, and production gap checklist.
