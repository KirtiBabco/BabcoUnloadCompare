# Source basis

This build was produced from two uploaded Markdown files:

1. **Technical Master Guidelines** — architecture, database safety, Web Forms build/static validation, packaging and security baseline.
2. **Prompt 1 — Babco Unload Compare Module** — functional source of truth for PO selection, quantities, pallets, Excel/document intake, verification, history, audit, export and print.

Project-specific functional requirements take precedence over generic technical guidance where applicable.


## v1.1.4 live Babco mapping decision

The runtime error exposed these actual `dbo.UOS_OrderDetail` columns: `OrderDetailId`, `OrderId`, `SKU`, `Qty`, `Price`, `Amount`, `ItemName`, `AvgSalesDemand`, `Inventory`, `InvMonths`, `Notes`, `InitialQty`, `InitialQtyBy`, `InitialQtyOn`, `HtsCode`, `HTSTariff`, `TrumpTariff`. Therefore the application no longer expects `ItemId`/`ProductId` in the detail table.

For the requested grid, the source mapping is intentionally narrow: `SKU = UOS_OrderDetail.SKU`, `SHIP QTY = SUM(UOS_OrderDetail.Qty)` per selected order/SKU, and `PACKING = Item.ItemName by SKU` when available with `UOS_OrderDetail.ItemName` fallback. REC QTY, Expiry date, Nitrogen, pallet columns, DIFF and TOTAL are receiving-side fields. Optional source/header values are blank when unavailable.

## v1.2.0 database boundary

The live Babco order source remains `UOS_Order`, `UOS_OrderDetail`, and `Item`, accessed through `BabcoSupportConnectionString`. Unload Compare application-owned `UC_*` tables are accessed through `UnloadCompareConnectionString`. This allows Azure/new application database deployment without copying or altering Babco source tables.
