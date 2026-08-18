# Validation Report - v1.2.0

## Scope verified

- Editable Container Number on main receiving header.
- Unload Date persisted end-to-end.
- Unload By 1 / 2 / 3 persisted end-to-end.
- Unload Date + Unload By 1 required before Ready for Verification; Draft/In Progress remain permissive.
- Header fields shown in Details, History and Print.
- Header changes audited by stored procedure.
- Five-pallet limit retained.
- Positive-quantity SKU rule retained.
- Current-PO Excel download/fill/upload workflow retained.
- Left-side responsive navigation retained.
- Application DB and Babco supporting DB use separate named connection strings.
- Application schema scripts do not create/alter Babco UOS/Item source tables.

## Static checks

- `.csproj`, `Web.config`, and `packages.config` XML parse: PASS
- `System.Web`, `System.Web.Extensions`, `System.Web.Services` references: PASS
- JavaScript `node --check` for all project JS: PASS
- C# lexical string/comment/brace scan: PASS
- CSS brace scan: PASS
- ASPX duplicate static IDs scan: PASS
- Required project Compile/Content/None paths exist: PASS
- Two connection strings present: PASS
- `BabcoOrderSource` uses support connection for UOS/Item and app connection for existing receiving lookup: PASS
- `UnloadDate`, `UnloadBy1`, `UnloadBy2`, `UnloadBy3`, `ContainerNumber` present through model/data/schema/procedure/UI paths: PASS
- `01_Schema.sql` / `02_StoredProcedures.sql` have no hard-coded `USE [Babco]`: PASS

## Runtime boundary

A real SQL Server / IIS / Azure runtime is still required to execute the database scripts, rebuild the .NET Framework WebForms project, and test both configured SQL endpoints. Static validation does not replace that environment-specific test.
