# Database install / connection boundary - v1.2.0

Unload Compare now uses **two separate SQL connection strings**.

## 1. Application database

Connection name: `UnloadCompareConnectionString`

This database owns only the Unload Compare objects:

- `UC_POHeaderSource`
- `UC_POItemSource`
- `UC_ReceivingHeader`
- `UC_ReceivingItem`
- `UC_ReceivingPallet`
- `UC_UploadedDocument`
- `UC_ImportHistory`
- `UC_Verification`
- `UC_AuditLog`
- `usp_UC_*` stored procedures

Run here, in order:

1. `01_Schema.sql`
2. `02_StoredProcedures.sql`

Both scripts are additive/idempotent and intentionally do **not** hard-code `USE [Babco]`, so they can run against a new Azure database such as `BabcoUnloadCompareDb`.

v1.2.0 adds to `UC_ReceivingHeader`:

- `UnloadDate`
- `UnloadBy1`
- `UnloadBy2`
- `UnloadBy3`

`ContainerNumber` already exists and is now editable in the receiving screen.

## 2. Babco supporting/source database

Connection name: `BabcoSupportConnectionString`

This connection is read for:

- `dbo.UOS_Order`
- `dbo.UOS_OrderDetail`
- `dbo.Item`

Exact mapping:

- `UOS_Order.OrderId -> UOS_OrderDetail.OrderId`
- PO = `UOS_Order.OrderNo`
- SKU = `UOS_OrderDetail.SKU`
- SHIP QTY = SKU-wise `SUM(UOS_OrderDetail.Qty)` where total is greater than zero
- PACKING = `Item.ItemName` joined by SKU, fallback `UOS_OrderDetail.ItemName`

The application never creates or alters these Babco supporting tables.

Read-only support diagnostics:

- `04_SourceMapping_Diagnostics.sql`
- `05_Connection_Quick_Test.sql`
- `06_Live_Order_Item_Load_Test.sql`
- `07_Positive_Qty_Item_Test.sql`

These scripts still target the Babco support database and can be adjusted if that database has a different name in another environment.
