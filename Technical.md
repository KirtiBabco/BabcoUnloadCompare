# Technical Master Guidelines

> Reusable technical baseline for any software project. Replace values inside `<...>` with project-specific values. Project-specific instructions always override this file when explicitly stated.

## 1. Project Technical Baseline

- Project Name: `<PROJECT_NAME>`
- Solution / Repository: `<SOLUTION_OR_REPOSITORY_NAME>`
- Primary Runtime: `<RUNTIME>`
- Backend: `<BACKEND_STACK>`
- Frontend: `<FRONTEND_STACK>`
- Database: `<DATABASE_ENGINE>`
- Database Name: `<DATABASE_NAME>`
- Hosting: `<IIS / CONTAINER / CLOUD / OTHER>`
- Source Control: Git
- Primary Branch: `main`
- Build Configuration: `Debug` and `Release`
- Environments: `DEV` and `PROD`

## 2. Source of Truth

Use this precedence whenever configuration or documentation conflicts:

1. Explicit project requirement for the current task.
2. Runtime environment / protected secret store.
3. Database configuration and current schema.
4. Application configuration files.
5. Source code.
6. Documentation and examples.

Rules:

- Do not duplicate the same configurable value in multiple places unless backward compatibility requires it.
- Runtime secrets must never use Markdown/documentation as the source of truth.
- Database migrations must be additive and idempotent whenever possible.
- Existing working data and configuration must be preserved unless a destructive migration is explicitly approved.

## 3. Architecture Rules

- Keep UI, business logic, data access, integration logic, and infrastructure concerns separated.
- Prefer server-side orchestration for AI/API/database operations that use credentials.
- Reuse shared helpers/services instead of creating provider-specific duplicate flows.
- Keep provider-specific behavior behind a common contract.
- Keep deployment/integration code isolated from core business logic.
- Every external integration must support clear success, failure, timeout, and diagnostic paths.
- Use deterministic naming for generated project resources such as repository, IIS site, app pool, package, branch, and workspace names.

## 4. DEV / PROD Configuration Model

Every external AI/API provider should support independent DEV and PROD configuration where relevant.

Each environment can have separate:

- Provider
- API key / secret reference
- Endpoint
- API version
- Model
- Enabled state
- Default state
- Timeout / retry policy

Recommended routing:

- DEV: analysis, requirement interpretation, task generation, review, diagnostics, experimentation.
- PROD: source generation, coding, packaging, production automation, deployment-sensitive operations.

Rules:

- DEV and PROD may use the same provider or different providers.
- Copying DEV settings to PROD must never automatically copy protected secrets unless explicitly designed and approved.
- Existing single-environment configurations should migrate to DEV first; create PROD records without exposing/copying secret values.
- UI must clearly show which environment is being edited/tested.

## 5. AI / Provider Integration Contract

For projects that use AI providers:

- Use one shared provider call result contract.
- Normalize provider responses before the UI consumes them.
- Treat a response as failed only when an explicit error/failure signal exists.
- Successful rows should expose explicit success metadata when possible, for example:
  - `IsSuccess = true`
  - `ResultType = "Task"` or another defined result type.
- Normalize common key aliases/case variations before rendering, for example `Title`, `TaskTitle`, `Task`, `Name`.
- Support JSON inside markdown fences, wrapped objects, common casing/snake-case differences, and safe trailing-comma cleanup when parsing AI task output.
- Retry malformed AI JSON at most once unless the project explicitly requires a different policy.
- Provider error rows must never be rendered as valid tasks.
- Preserve the original provider error in diagnostic history.
- Do not claim an image was visually analyzed if the selected model does not support vision.
- Only send multimodal/image payloads when the provider/model capability supports them.
- Local/self-hosted providers must be disabled until their local endpoint/model is available.
- New provider records should be inserted idempotently and disabled by default.
- Existing provider records and secrets should not be overwritten during catalog updates.

## 6. Database Engineering

- Prefer stored procedures or parameterized queries for application data operations.
- New schema changes should use safe guards such as `IF OBJECT_ID(...) IS NULL`, `IF COL_LENGTH(...) IS NULL`, or equivalent.
- Migration scripts must be orderable and safe for existing databases.
- Keep short status/approval codes in short columns and long diagnostic text in a dedicated `NVARCHAR(MAX)` / text field.
- Never put long error/progress messages into a short approval/status column.
- Use transactions for lock-sensitive operations such as task checkout, ownership transfer, merge state, or package gates.
- For concurrent task checkout, use a database locking strategy that prevents two users from obtaining the same task.
- Preserve backward compatibility when a database may be partially migrated.
- Existing records should be migrated, mapped, or soft-hidden rather than deleted unless deletion is explicitly required.

## 7. Project Artifact Layout

For generated or managed projects, use a predictable root structure:

```text
<PROJECTS_ROOT>/
  P<ProjectId>_<ProjectName>/
    Input/
    Source/
    Workspaces/
    Packages/
```

Recommended meanings:

- `Input` - requirement, mockup, uploaded reference files.
- `Source` - current generated/working application source.
- `Workspaces` - isolated per-user/per-task Git worktrees.
- `Packages` - versioned full-project ZIP packages and latest-package marker.

Rules:

- Sanitize project names before using them in paths.
- Prevent path traversal.
- Validate that all file operations stay under an allowed root.
- Verify write access before generation or packaging.
- Preserve `.git` when refreshing generated source if the repository is intentionally reused.
- Normalize read-only attributes and use bounded retry handling when replacing generated files on Windows.

## 8. Versioned Packaging

- Full project output must be versioned.
- Do not overwrite a prior successful package.
- Create ZIP files atomically: write a temporary ZIP in the target package directory, validate it, then move/rename it to the final versioned filename.
- Clean partial temporary ZIPs after failure.
- Latest-package download should return the latest successful package; it should not silently create a new package unless the product explicitly defines repair-on-download behavior.
- Package history should record version, filename/path, timestamp, status, source/project reference, and error details when applicable.
- Runtime/final packages should normally exclude:
  - `.git`
  - `.vs`
  - `bin`
  - `obj`
  - caches
  - temporary files
  - `.user`
  - `.suo`
  - local secret files

## 9. Git Engineering

- Use `main` as the protected integration branch unless a project says otherwise.
- Do not use force push in automated project setup flows.
- Repository name, description, remote URL, local path, and default commit message may be derived from the active project to reduce manual entry.
- Save project-to-repository linkage by stable ProjectId, not only by project name.
- Prefer the generated project `Source` folder when it exists; otherwise use the configured repository root.
- Token/credential storage must be protected and never returned to the browser after save.
- For parallel development, use per-task branches and isolated worktrees.

Suggested branch format:

```text
feature/task-<TaskId>-<sanitized-task-name>
```

Suggested workspace format:

```text
Workspaces/M<MemberId>/T<TaskId>_<TaskName>
```

## 10. Collaboration and Merge Engineering

- Task checkout must acquire a transactional lock before branch/workspace creation.
- A task already locked by one developer cannot be checked out by another developer.
- Each task must retain branch, workspace, commit hash, owner, and review state.
- The submitter cannot approve their own task.
- Human approval merges safely into `main`.
- On merge conflict:
  - Abort the merge.
  - Preserve a valid `main` branch.
  - Mark the task as Merge Conflict / blocked.
  - Block final packaging until resolved.
- Handoff must be an audited ownership transfer, not silent reassignment.

## 11. Notifications / Webhooks

For Teams, Power Automate, Slack, or similar workflows:

- Send UTF-8 JSON.
- Set the correct JSON `Content-Type` and `Accept` header.
- Use TLS 1.2+.
- Use explicit request/read-write timeouts.
- Read and log the response body for both success and error responses.
- Capture the body of web exceptions when available.
- Notification-log failure should not incorrectly convert a successful remote notification into a failed remote call.
- Allow direct test actions from the current configured URL.
- Keep a fallback endpoint only when the project explicitly permits it.

## 12. IIS / Hosting Rules

For classic ASP.NET/IIS projects:

- Generate site/app-pool/physical-path defaults from the project where possible.
- Only expose necessary deployment inputs in the UI.
- Validate that the configured physical path stays under an allowed root.
- Give the application pool only the required permissions (normally Modify on the project artifact root, not broad machine-level access).
- Perform a health check after deployment/finalization.

## 13. ASP.NET Web Forms Build Rules (When Applicable)

- Project must be an ASP.NET Web Application, not a Class Library.
- `.csproj` should include Web Application `ProjectTypeGuids`.
- Import `Microsoft.WebApplication.targets`.
- Include valid IIS Express / `ProjectExtensions > VisualStudio > FlavorProperties > WebProjectProperties` settings when F5 launch is required.
- Set the real entry page (commonly `Default.aspx` or `Login.aspx`) as the startup page.
- Enable ASPX debugging and automatic development server startup where required.
- Keep `CodeBehind`, `Inherits`, namespace, partial class, and `.designer.cs` synchronized.
- Validate `.aspx`, `.master`, `.ascx`, and `Global.asax` directive mappings.
- In designer files, use:

```csharp
global::System.Web.UI.WebControls.ContentPlaceHolder
```

Never use the invalid:

```csharp
System.Web.UI.ContentPlaceHolder
```

- Avoid ambiguous custom type names such as `DriveInfo` when `System.IO.DriveInfo` is in scope. Prefer names such as `SharePointDriveInfo` or `GraphDriveInfo`.
- Entity Framework package/reference paths must be valid, single-line paths with no hidden/control characters.
- Validate Debug/Release configurations and output/intermediate paths.
- Generated projects must open the actual functional application flow, not a generic placeholder landing page.

## 14. Build and Static Validation

Before packaging or delivery, validate as applicable:

- Solution references the correct project path.
- `.csproj` XML parses.
- C# namespace/attribute usage is cross-checked against required framework assembly references (especially `System.Web`, `System.Web.Extensions`, and `System.Web.Services`).
- `Web.config` / app config XML parses.
- `packages.config` XML parses.
- Every `Compile`, `Content`, `None`, `Reference`, `HintPath`, and `Import` path is valid.
- No path contains newline, carriage return, tab, hidden/control, or illegal characters.
- Required files included in the project actually exist.
- JavaScript syntax passes.
- CSS braces are balanced.
- C# lexical braces/strings/comments are structurally valid when a compiler is unavailable.
- No duplicate HTML/server-control IDs.
- No invalid WebForms designer declarations.
- No ambiguous known model/type collisions.
- Secret-pattern scan passes.
- ZIP integrity/CRC passes.
- Delivery ZIP does not contain build/cache/source-control/secret artifacts.

## 15. Runtime Validation Boundary

Static validation is not a substitute for runtime validation.

On the target environment, verify:

1. Restore packages/dependencies.
2. Run required database migrations in order.
3. Clean build artifacts.
4. Rebuild the full solution and check the Build Output, not only the Error List.
5. Start the configured entry page.
6. Test database connectivity.
7. Test each configured external API/provider.
8. Test Git operations and remote push/merge if enabled.
9. Test notification workflow/webhook delivery if enabled.
10. Test IIS/deployment/health checks if enabled.
11. Run end-to-end generation/business workflows.
12. Validate the final versioned package on a clean extraction.

## 16. Technical Definition of Done

A technical task is complete only when:

- Required code/config/database changes are included.
- Existing functionality is preserved or intentionally migrated.
- Build/static checks pass.
- Error handling and diagnostics are present.
- Security rules are satisfied.
- Frontend and backend contracts agree.
- Required runtime tests are documented or completed.
- Final packaging is clean, versioned, and reproducible.

## 17. Visual Studio WebForms Project Unloaded - Mandatory Solution / Project Fix

This rule was added after the Babco Unload Compare solution opened as:

```text
Solution 'BabcoUnloadCompare' (0 of 1 project)
BabcoUnloadCompare.Web (unloaded)
```

For classic ASP.NET Web Application projects, validate both the `.sln` project factory GUID and the `.csproj` Web Application flavor before packaging.

### Correct `.sln` rule

The project entry in the solution must use the standard C# project type GUID:

```text
{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}
```

Example:

```text
Project("{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}") = "BabcoUnloadCompare.Web", "BabcoUnloadCompare.Web\BabcoUnloadCompare.Web.csproj", "{PROJECT-GUID}"
EndProject
```

Do not use the ASP.NET Web Application flavor GUID `{349C5851-65DF-11DA-9384-00065B846F21}` as the outer `Project(...)` type GUID in the `.sln` entry.

### Correct `.csproj` rule

The `.csproj` must still declare ASP.NET Web Application + C# project flavors:

```xml
<ProjectTypeGuids>{349C5851-65DF-11DA-9384-00065B846F21};{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}</ProjectTypeGuids>
```

It must also import:

```xml
<Import Project="$(MSBuildBinPath)\Microsoft.CSharp.targets" />
<Import Project="$(VSToolsPath)\WebApplications\Microsoft.WebApplication.targets"
        Condition="Exists('$(VSToolsPath)\WebApplications\Microsoft.WebApplication.targets')" />
```

Before delivering any `.sln` WebForms ZIP, validate:

- Solution project path exists exactly as written.
- `.sln` project type GUID is the C# GUID.
- `.csproj` contains Web Application + C# `ProjectTypeGuids`.
- `Microsoft.WebApplication.targets` import is present.
- Target framework is installed/supported on the target Visual Studio machine.
- ASP.NET and web development workload is installed in Visual Studio.
- Debug/Release `Any CPU` output paths exist.
- `ProjectExtensions` contains valid IIS/IIS Express startup settings and a real start page.

If Visual Studio still shows an old unloaded state after the files are corrected:

1. Close Visual Studio.
2. Delete the solution-local `.vs`, `bin`, and `obj` folders.
3. Reopen the corrected `.sln`.
4. Right-click the unloaded project and choose **Reload Project** if required.
5. If Visual Studio reports that the project type is unsupported, install/repair **ASP.NET and web development** and the required **.NET Framework targeting pack** from Visual Studio Installer.
6. Clean and Rebuild the solution and verify the **Build Output** window.

This validation is mandatory for future ASP.NET WebForms ZIP packages.

## 18. Babco Unload Compare - Current Project Override

Project name: `BabcoUnloadCompare`

Required stack:

- ASP.NET Web Forms Web Application
- C# / .NET Framework 4.7.2
- JavaScript + AJAX `[WebMethod]`
- Microsoft SQL Server
- No MVC / Web API conversion

### Database source

Use database `Babco` and the Web.config connection-string key named `ConnectionString`.

The current live order source is:

- Header/order table: `dbo.UOS_Order`
- Child/order-detail table: `dbo.UOS_OrderDetail`
- Item master: `dbo.Item`
- SKU: `Item.SKU`
- Item / packing name: `Item.ItemName`

The exact order-key, detail foreign-key, PO-number, and shipped-quantity column names may differ in the existing Babco schema. The application must not guess destructively. It must either:

1. Auto-detect a supported exact column name from the live schema, or
2. Prefer schema-driven zero-config mapping for known business columns; use explicit configuration only when the user explicitly requires it.

Provide a SQL diagnostic script that lists columns from `UOS_Order`, `UOS_OrderDetail`, and `Item` so a missing mapping can be corrected without code changes.

Runtime database credentials belong in `Web.config` / protected configuration and must not be duplicated in this Markdown document.

### Required default Unload Compare format

The receiving screen, Excel record download, Excel import, and print report must support this core layout in this order:

```text
SKU | PACKING | SHIP QTY | REC QTY | Expiry date | Nitrogen | DIFF ( +/-) | PAL-1 | PAL-2 | PAL-3 | PAL-4 | PAL-5 | TOTAL
```

Rules:

- `SKU` comes from `Item.SKU`.
- `PACKING` comes from `Item.ItemName`.
- `SHIP QTY` comes from the selected order/detail shipped/ordered quantity.
- `REC QTY` is warehouse received quantity.
- `DIFF ( +/-) = REC QTY - SHIP QTY`.
- `PAL-1` through `PAL-5` are the only receiving pallet columns in the current requirement.
- The application must still allow PAL-7, PAL-8, and additional pallets dynamically when required.
- `TOTAL` is the sum of entered pallet quantities when pallet entry is used.
- Expiry date and Nitrogen are editable receiving fields and must be saved with the receiving item.
- Excel import must validate SKU against the selected PO and never silently discard unmatched rows.
- If both REC QTY and pallet quantities are supplied by Excel, flag a validation error when REC QTY does not equal pallet TOTAL.
- Excel export must keep the same core column sequence and include exactly PAL-1 through PAL-5.
- A downloadable default `.xlsx` template must be included in the project and exposed through the UI.

### Example default rows

```text
ANFRC400 | Anand Fryums - Round (Color) - 20 x 400 g (FR-3) | 108 | 108 | Jun-28 | | 0
ANFRP400 | Anand Fryums - Round (Plain) - 20 x 400 g (FR-4) | 80  | 80  | Jun-28 | | 0
ANFSC400 | Anand Fryums - Star (Color) - 20 x 400 g (FR-5) | 50  | 50  | Jun-28 | | 0
ANFSP400 | Anand Fryums - Star (Plain) - 20 x 400 g (FR-6) | 20  | 20  | Jun-28 | | 0
```

## 19. Reusable Prompt - Babco Unload Compare Build / Repair

Build or repair the complete **Babco Unload Compare** ASP.NET WebForms application as a runnable Visual Studio solution. Fix any `.sln` / `.csproj` issue that causes `0 of 1 project` or `project unloaded`. The `.sln` must use the C# project type GUID and the `.csproj` must keep ASP.NET Web Application `ProjectTypeGuids`, WebApplication targets, valid Debug/Release Any CPU output paths, IIS Express startup configuration, synchronized WebForms designers, and `UnloadCompare.aspx` as the functional start page.

Use SQL Server database `Babco` through the `ConnectionString` Web.config entry. Load orders from `UOS_Order`, child rows from `UOS_OrderDetail`, and item identity from `Item` using `Item.SKU` and `Item.ItemName`. Preserve existing Babco tables and add only Unload Compare tables/stored procedures. Where exact live UOS key/quantity column names are not known, auto-detect safe common names and provide Web.config overrides plus a schema-diagnostic SQL script instead of hardcoding unverified column names.

The main receiving grid and all Excel/print output must use the core format `SKU, PACKING, SHIP QTY, REC QTY, Expiry date, Nitrogen, DIFF ( +/-), PAL-1, PAL-2, PAL-3, PAL-4, PAL-5, TOTAL`. The current business requirement is fixed at five pallet columns; do not render PAL-6 or an additional-pallet control unless a later explicit requirement changes this. Calculate differences immediately, save Expiry date and Nitrogen, preserve verification/history/audit/document-upload workflows, support `.xls/.xlsx` import preview with unmatched-SKU handling, do not provide a separate blank/default-format download. The primary Excel workflow must be **Download current PO records → fill that same workbook → Upload Filled Excel → preview → apply**. Include a working record-filled Excel download/export.

Before ZIP delivery, validate source-to-framework-reference compatibility (including mandatory `System.Web.Services` reference when `[WebMethod]` is used), `.sln` project loading structure, `.csproj` XML and all included paths, Web.config XML, packages.config XML, JavaScript syntax, CSS structure, WebForms designer types, handler/code-behind mappings, SQL script presence, Excel download/import round-trip contract, and ZIP CRC. **Also run a lexical scan across every C# source file and reject the package if any ordinary string literal crosses a physical newline or if any normal/verbatim string, character literal, or block comment is unterminated.** For `CS1010`, fix the first broken string and rebuild before treating following `CS1001` / `CS1002` / `CS1513` errors as independent defects. Document the clean-extract Visual Studio run steps and the project-unloaded recovery steps in README. Also prevent IIS Express HTTP 403.14 at `/` by shipping a real default entry page, configuring `Web.config` `defaultDocument`, and aligning `.csproj` `StartAction` / `StartPageUrl` with an existing functional page.


## 20. C# Multiline SQL String / CS1010 Build Rule

This rule was added after the Babco Unload Compare build reported the following Visual Studio errors in `Services/BabcoOrderSource.cs` around lines 123-125:

- `CS1010 Newline in constant`
- `CS1002 ; expected`
- `CS1001 Identifier expected`
- `CS1513 } expected`

These downstream errors can all be caused by one broken C# string literal. Fix the **first `CS1010`** first, then rebuild before treating the remaining errors as independent defects.

### Root cause pattern

A normal C# string literal cannot continue across a physical newline. This is invalid when the SQL fragment crosses the next source line:

```csharp
// Invalid: ordinary string literal is left open across a physical newline.
... + Q(m.OrderNumberColumn) + " AS nvarchar(100))=@PONumber
GROUP BY ...
```

When a concatenated SQL statement is using multiline/verbatim fragments, the continuing fragment must also be verbatim, or the newline must be concatenated explicitly.

### Correct pattern

```csharp
var detailSql = @"SELECT
 CAST(i." + Q(m.ItemSkuColumn) + @" AS nvarchar(80)) AS SKU,
 CAST(i." + Q(m.ItemNameColumn) + @" AS nvarchar(250)) AS ItemName
FROM " + QT(_orderTable) + @" o
INNER JOIN " + QT(_detailTable) + @" d ON d." + Q(m.DetailOrderKeyColumn) + "=o." + Q(m.OrderKeyColumn) + @"
INNER JOIN " + QT(_itemTable) + @" i ON i." + Q(m.ItemKeyColumn) + "=d." + Q(m.DetailItemKeyColumn) + @"
WHERE CAST(o." + Q(m.OrderNumberColumn) + @" AS nvarchar(100))=@PONumber
GROUP BY i." + Q(m.ItemSkuColumn) + ",i." + Q(m.ItemNameColumn) + @"
ORDER BY i." + Q(m.ItemSkuColumn) + ";";
```

The important fix is the `@` before the string fragment that physically continues to the next line:

```csharp
+ @" AS nvarchar(100))=@PONumber
```

### Mandatory prevention rules

For every C# file that constructs multiline SQL or other multiline text:

- Never allow an ordinary `"..."` string literal to cross a physical newline.
- Use `@"..."` for a fragment that contains source newlines, or explicitly concatenate `Environment.NewLine` / separate quoted fragments.
- When mixing `@"..."` fragments with dynamic expressions, re-check every transition from `+ expression +` back into string text.
- After any SQL-string edit, scan the **entire `.cs` file** for unterminated normal strings, verbatim strings, character literals, and block comments.
- Treat a large group of `CS1001`, `CS1002`, `CS1513`, and similar errors immediately following `CS1010` as likely cascade errors until the first broken string is fixed and the solution is rebuilt.
- Before ZIP delivery, the validation report must include a C# lexical string/comment scan with zero `newline in normal string` findings.
- On a Windows build machine, always verify the final result using **Build Output -> Rebuild Solution**, not Error List alone.

### Babco Unload Compare repair record

For `BabcoUnloadCompare` v1.1.1, the broken fragment in `Services/BabcoOrderSource.cs` was changed from a normal string continuation to a verbatim continuation. The corrected line is logically:

```csharp
WHERE CAST(o." + Q(m.OrderNumberColumn) + @" AS nvarchar(100))=@PONumber
```

This specific check is mandatory for all future full-project ZIP deliveries.

## 21. ASP.NET WebForms `System.Web.Services` / `[WebMethod]` Reference Rule

This rule was added after the Babco Unload Compare build repeatedly reported errors such as:

```text
CS0234 The type or namespace name 'Services' does not exist in the namespace 'System.Web'
CS0246 The type or namespace name 'WebMethodAttribute' could not be found
CS0246 The type or namespace name 'WebMethod' could not be found
```

### Root cause

`using System.Web.Services;` and `[WebMethod]` depend on the **.NET Framework assembly `System.Web.Services.dll`**. A project can already reference `System.Web` and `System.Web.Extensions` and still fail to compile if `System.Web.Services` is not explicitly referenced by the `.csproj`.

For classic ASP.NET Web Application projects that use page methods, this is a project-file/reference problem, not a reason to remove the `using System.Web.Services;` directive or replace `[WebMethod]`.

### Mandatory `.csproj` references for page-method AJAX

When any `.cs` file contains `using System.Web.Services;`, `[WebMethod]`, or `[WebMethodAttribute]`, the project must contain:

```xml
<Reference Include="System.Web" />
<Reference Include="System.Web.Extensions" />
<Reference Include="System.Web.Services" />
```

`System.Web.Services` is a framework assembly reference. Do not add it as a random NuGet package.

### WebForms AJAX reference matrix

Before packaging, scan source usage and verify the corresponding project references:

| Source usage | Required `.csproj` framework reference |
|---|---|
| `System.Web.UI`, `HttpContext`, `IHttpHandler` | `System.Web` |
| `System.Web.Script.Serialization`, ScriptManager / ASP.NET AJAX types | `System.Web.Extensions` |
| `System.Web.Services`, `[WebMethod]`, `[WebMethodAttribute]` | `System.Web.Services` |
| `System.Configuration.ConfigurationManager` | `System.Configuration` |
| `System.Data.SqlClient`, `DataTable`, `DataSet` | `System.Data` |
| `ZipArchive` | `System.IO.Compression` |
| ZIP file extensions / `ZipFile` support | `System.IO.Compression.FileSystem` |

### Mandatory pre-package validation

For every ASP.NET WebForms full-project ZIP:

1. Parse the `.csproj` as XML.
2. Scan all `.cs` files for `using System.Web.Services`, `[WebMethod]`, and `[WebMethodAttribute]`.
3. If any of those tokens exist, fail packaging unless `<Reference Include="System.Web.Services" />` exists.
4. Scan for `System.Web.Script.` usage and fail packaging unless `<Reference Include="System.Web.Extensions" />` exists.
5. Confirm `<Reference Include="System.Web" />` exists for all WebForms projects.
6. Confirm all framework references are under an `<ItemGroup>` and are not malformed/broken paths.
7. Run the existing designer checks, C# lexical checks, solution/project load checks, and path checks.
8. On Windows, run **Clean Solution -> Rebuild Solution** and inspect **Build Output**, not only Error List.

### Repair procedure when these errors appear

1. Open the `.csproj` and add the missing framework reference:

```xml
<Reference Include="System.Web.Services" />
```

2. Keep `using System.Web.Services;` in the affected page code-behind.
3. Keep `[WebMethod]` on static AJAX page methods.
4. Close Visual Studio.
5. Delete `.vs`, `bin`, and `obj`.
6. Reopen the `.sln`.
7. Restore NuGet packages.
8. Clean Solution.
9. Rebuild Solution and check Build Output.
10. If `System.Web.Services` still cannot resolve, install/repair **ASP.NET and web development** plus the **.NET Framework 4.7.2 targeting/developer pack** in Visual Studio Installer.

### Babco Unload Compare repair record

For `BabcoUnloadCompare` v1.1.2, `BabcoUnloadCompare.Web.csproj` must contain all three WebForms/AJAX references:

```xml
<Reference Include="System.Web" />
<Reference Include="System.Web.Extensions" />
<Reference Include="System.Web.Services" />
```

The pages `UnloadCompare.aspx.cs`, `UnloadCompareDetails.aspx.cs`, and `UnloadCompareHistory.aspx.cs` use `[WebMethod]`; therefore the `System.Web.Services` reference is mandatory. This check must remain part of every future Babco WebForms package validation so this recurring error does not return.

## 22. Mandatory WebForms Reference-Audit Prompt Addition

For every future ASP.NET WebForms build/repair request, add this requirement to the project-generation prompt:

> Before delivery, scan every C# source file for framework namespaces/attributes and verify that the `.csproj` contains the required framework assembly references. At minimum, if any file uses `System.Web.Services`, `[WebMethod]`, or `[WebMethodAttribute]`, require `<Reference Include="System.Web.Services" />`; if any file uses `System.Web.Script.*`, require `<Reference Include="System.Web.Extensions" />`; all WebForms projects must reference `System.Web`. Reject the ZIP when source usage and `.csproj` references do not match. Do not treat a successful XML/path scan as sufficient. On the target Windows machine, run Clean + Rebuild and inspect Build Output.

## 23. IIS Express HTTP 403.14 / Default Document / Start Page Rule

This rule was added after Babco Unload Compare successfully loaded under IIS Express but F5 opened the site root and returned:

```text
HTTP Error 403.14 - Forbidden
The Web server is configured to not list the contents of this directory.
Module: DirectoryListingModule
Handler: StaticFile
Requested URL: http://localhost:<port>/
```

### What this error actually means

`403.14` at the application root usually means IIS/IIS Express reached the configured physical Web Application path, but the request was `/` and IIS did not resolve a default document. **Do not enable directory browsing as the application fix.** A WebForms business application should have a deterministic entry page.

### Mandatory three-layer fix for generated WebForms projects

For every generated classic ASP.NET Web Application that must run with F5:

1. Include a real `Default.aspx` (or the explicitly approved entry page) in the project.
2. Configure `system.webServer/defaultDocument` in `Web.config` with the physical entry page first.
3. Configure the `.csproj` WebProjectProperties with an explicit specific start page.

Required `Web.config` pattern:

```xml
<system.webServer>
  <defaultDocument enabled="true">
    <files>
      <clear />
      <add value="Default.aspx" />
      <add value="UnloadCompare.aspx" />
    </files>
  </defaultDocument>
</system.webServer>
```

Required `.csproj` WebProjectProperties pattern:

```xml
<WebProjectProperties>
  <UseIIS>True</UseIIS>
  <IISUrl>http://localhost:<port>/</IISUrl>
  <StartAction>SpecificPage</StartAction>
  <StartPageUrl>Default.aspx</StartPageUrl>
</WebProjectProperties>
```

For Babco Unload Compare, `Default.aspx` must redirect to `~/UnloadCompare.aspx`. This makes both `http://localhost:<port>/` and Visual Studio F5 reach the real module.

### Mandatory pre-package validation

Before every WebForms ZIP delivery, fail validation unless all applicable checks pass:

- The configured default-document file physically exists.
- The default-document file is included as `<Content Include="..." />` in the `.csproj`.
- Its code-behind and designer files are included when the page uses `CodeBehind`.
- `Web.config` parses and contains an enabled `system.webServer/defaultDocument` entry.
- `Default.aspx` (or the approved entry page) appears first in the default-document list.
- `.csproj` contains `<StartAction>SpecificPage</StartAction>`.
- `.csproj` contains a valid `<StartPageUrl>` pointing to an existing content page.
- The start page is a real functional flow or redirects to one; never ship a placeholder landing page.
- Do not solve `403.14` by enabling directory browsing.
- After changing startup/default-document settings, test from a **fresh extraction** after deleting `.vs`, `bin`, and `obj`.

### Repair procedure when 403.14 appears

1. Confirm the IIS detailed error Requested URL ends in `/` and the physical path points to the expected Web Application folder.
2. Confirm the intended entry `.aspx` file exists.
3. Add/configure `Default.aspx` and `system.webServer/defaultDocument`.
4. Add/verify `.csproj` `StartAction=SpecificPage` and `StartPageUrl=Default.aspx`.
5. Close Visual Studio and delete `.vs`, `bin`, and `obj`.
6. Reopen the `.sln`, set the Web project as Startup Project, Clean Solution, Rebuild Solution, and press F5.
7. Verify both `http://localhost:<port>/` and `http://localhost:<port>/UnloadCompare.aspx` reach the application.

### Reusable prompt addition

For all future WebForms build/repair tasks: **prevent IIS Express HTTP 403.14 by shipping a physical default entry page, configuring Web.config defaultDocument, and aligning Visual Studio StartAction/StartPageUrl with an existing functional page. Validate these items before packaging. Never rely only on the developer manually choosing “Set as Start Page,” and never enable directory browsing as the product fix.**


## 24. Babco UOS Zero-Config Column Mapping / Order-wise SKU Rule

This rule was added after Unload Compare reported:

```text
Cannot auto-map BabcoOrder.DetailItemKeyColumn. Available columns: OrderDetailId, OrderId, SKU, Qty, Price, Amount, ItemName, ...
Set the exact column name in Web.config appSettings.
```

### Root cause

The generated integration incorrectly assumed that `dbo.UOS_OrderDetail` must contain an `ItemId`/`ProductId` foreign key. The real detail schema already contains `OrderId`, `SKU`, `Qty`, and `ItemName`, so forcing an item-key mapping created unnecessary configuration and blocked a valid order.

### Permanent rule for this project

Do **not** require any `BabcoOrder.*Column` Web.config settings for the Unload Compare live source. The known business source is `Babco.dbo.UOS_Order` + `Babco.dbo.UOS_OrderDetail`; `Babco.dbo.Item` is optional enrichment only.

Use this mapping:

- Order/detail relationship: prefer `UOS_Order.OrderId` to `UOS_OrderDetail.OrderId`; if the header uses another primary key name, discover the header primary key and match the same/detail OrderId-style column automatically.
- `SKU`: `UOS_OrderDetail.SKU`.
- `SHIP QTY`: `SUM(UOS_OrderDetail.Qty)` grouped by the selected order and SKU.
- `PACKING`: prefer `Item.ItemName` using an SKU-to-SKU lookup; fall back to `UOS_OrderDetail.ItemName`; otherwise return an empty string.
- `UOM`, Vendor, Container, Receiving Date: use only when a safe matching source column exists; otherwise return blank/null.
- `REC QTY`, Expiry date, Nitrogen, DIFF, PAL-1+, TOTAL: receiving-side values; initialize blank until entered/imported.

### Order-wise SKU identity

Treat SKU as the logical item identity inside one order. Do not create duplicate receiving rows for repeated detail lines of the same SKU. Aggregate SHIP QTY by PO/order + SKU. Internal tables should retain surrogate integer primary keys for maintainability while enforcing business uniqueness with composite unique constraints, such as:

```sql
UNIQUE(PONumber, SKU)
UNIQUE(ReceivingId, SKU)
```

Do not replace those surrogate primary keys with a global SKU primary key because the same SKU legitimately appears on many orders.

### Missing-column behavior

The page must not ask the warehouse user to edit Web.config just because an optional field is absent. Map what exists and leave the rest blank. Only fail when a truly critical source required for the core grid cannot exist safely: missing `UOS_Order`, missing `UOS_OrderDetail`, no usable order linkage, no detail SKU, or no detail Qty/SHIP QTY.

### Mandatory pre-package validation

For Babco UOS integrations:

1. Reject code that requires `DetailItemKeyColumn`, `ItemId`, or `ProductId` when `UOS_OrderDetail.SKU` is available.
2. Confirm there are no `BabcoOrder.*Column` appSettings in `Web.config`.
3. Confirm `BabcoOrderSource.cs` maps detail `SKU` and `Qty` directly.
4. Confirm optional `Item` enrichment joins/looks up by SKU and cannot multiply SHIP QTY when duplicate Item rows exist. Prefer `OUTER APPLY TOP (1)` or another non-multiplying lookup.
5. Confirm order detail rows are grouped by SKU and summed for SHIP QTY.
6. Confirm the default UI starts REC QTY / Expiry / Nitrogen / pallet values blank.
7. Confirm internal database uniqueness remains order/receiving scoped (`PONumber + SKU`, `ReceivingId + SKU`).
8. Keep the read-only schema diagnostic SQL for troubleshooting, but never require it as normal user setup.

### Reusable prompt addition

For Babco database-bound modules: **prefer zero-configuration mapping when the live table already contains the required business columns. Map known columns directly, use SKU as an order-scoped logical key, aggregate duplicate detail lines by order + SKU, enrich from Item by SKU only when available, and leave optional fields blank. Do not block the app or ask the user to edit Web.config for missing optional columns.**

## Babco Order Item Positive-Quantity Rule

For Babco Unload Compare, the order item grid must represent actual shippable order lines, not placeholder/zero-quantity detail rows.

Mandatory mapping rule:

```sql
UOS_Order.OrderId -> UOS_OrderDetail.OrderId
UOS_OrderDetail rows -> GROUP BY SKU
SHIP QTY -> SUM(ISNULL(UOS_OrderDetail.Qty, 0))
Display/load item only when SUM(Qty) > 0
```

Rules:
- `Qty = 0` rows must not create an item in the receiving grid.
- `Qty IS NULL` is treated as zero and must not create an item by itself.
- If the same SKU occurs more than once for the same OrderId, aggregate all rows first, then apply `HAVING SUM(Qty) > 0`.
- The PO search summary `ItemCount` must use the same positive-quantity SKU rule as the item-load query so the displayed count and loaded grid cannot disagree.
- Do not filter only in JavaScript; enforce this rule in the SQL source query so Excel export, receiving save, history, and UI use the same source set.
- Before packaging, verify that both Search and Load queries contain the positive-quantity filter and that a regression query returns no loaded item with `ExpectedQty <= 0`.


## 26. Compact Full-Screen Receiving Grid / Five-Pallet Rule

This rule supersedes the older six-pallet/dynamic-pallet UI requirement for Babco Unload Compare.

### Current grid contract

```text
SKU | PACKING | SHIP QTY | REC QTY | Expiry date | Nitrogen | DIFF (+/-) | PAL-1 | PAL-2 | PAL-3 | PAL-4 | PAL-5 | TOTAL | STATUS | NOTES
```

Rules:

1. Show **exactly five pallet columns** (`PAL-1` through `PAL-5`) in receiving, details, print, Excel default format, Excel import, and Excel export.
2. Do not show `PAL-6`, `More pallets`, or dynamic additional-pallet controls unless the user explicitly changes the requirement later.
3. Use the full browser width for the receiving page; do not constrain the main page to a 1600px centered container.
4. Keep the pre-grid area compact: reduced top bar, hero, PO search, PO summary, and toolbar vertical spacing. Once a PO is loaded, hide nonessential hero/workflow text where practical.
5. Prefer a dense but readable warehouse grid: approximately 39px row height, compact numeric inputs, nowrap/ellipsis packing text with tooltip, and clear status coloring.
6. Use a viewport-aware grid height so the table consumes the remaining screen instead of pushing most rows below the fold.
7. Keep SKU sticky on desktop. Packing may also be sticky on wider screens, but must become non-sticky on tablet/mobile to avoid consuming most of the viewport.
8. Mobile/tablet must use responsive controls and intentional horizontal scrolling for the wide receiving grid; do not squeeze quantity inputs into unusable widths.
9. Default pagination is 15 rows, with 10 / 15 / 25 / 50 choices. Pagination changes only rendering; all loaded item data remains in `state.items` so save/export totals use the complete order.
10. Add a persistent bottom `ORDER TOTAL` row. It must total SHIP QTY, entered REC QTY, PAL-1..PAL-5 and pallet TOTAL across the **complete order**, not only the visible page. Show DIFF total only when all PO items have a received quantity to avoid a misleading partial difference.
11. Excel export and print reports should also contain an ORDER TOTAL row.
12. The downloaded PO workbook must contain five pallet columns and an ORDER TOTAL row; no separate blank/default-format workbook is required.

### Mandatory regression checks before packaging

- Search source/UI/docs for `PAL-6`, `Math.Max(6`, `<=6`, `More pallets`, and dynamic pallet controls; none may remain in the current Unload Compare flow.
- Assert main grid header count/order matches the five-pallet contract.
- Assert `ExcelImportService` only reads PAL-1..PAL-5.
- Assert Excel export and print use `maxPallet = 5`.
- Assert pagination uses source indices so edits update the correct `state.items` row.
- Assert ORDER TOTAL calculations iterate the complete `state.items`, not only the current page.
- Assert the record-filled Excel download header uses the approved columns and contains no PAL-6.
- Run JavaScript syntax checks and C# lexical checks before ZIP creation.

### Reusable prompt addition

For Babco warehouse receiving screens, make the item grid the dominant part of the viewport. Use full width, compact header/summary/actions, exactly five pallet inputs, dense readable rows, responsive horizontal scrolling, 15-row default pagination, and complete-order totals in a sticky footer. Never add extra pallet columns or large whitespace unless explicitly requested.

## 27. Left Sidebar Navigation / Excel Round-Trip Rule

### Navigation

1. Desktop application navigation must be on the **left side**, not in the page top bar.
2. The sidebar should remain fixed while the receiving grid uses the remaining viewport width.
3. Highlight the current navigation item.
4. On tablet/mobile, keep the same left-navigation concept as an off-canvas drawer with an overlay and a compact menu button.
5. Do not consume warehouse vertical space with a permanent multi-row mobile top menu.

### Excel round-trip

The warehouse Excel workflow is one workbook, not a blank-template workflow:

`Load PO → Download Excel with PO records → fill REC/Expiry/Nitrogen/PAL-1..PAL-5 → Upload the same workbook → preview → apply → save/verify`

Rules:

- Do **not** show or ship a separate `Download Format` / `DefaultFormat.ashx` action unless a later explicit requirement restores it.
- Downloaded Excel must already contain live selected-PO `SKU`, `PACKING`, and `SHIP QTY` records.
- The workbook column order remains `SKU, PACKING, SHIP QTY, REC QTY, Expiry date, Nitrogen, DIFF ( +/-), PAL-1, PAL-2, PAL-3, PAL-4, PAL-5, TOTAL`.
- Download should preserve any already-saved receiving values. Blank/unentered receiving quantities should be blank in the workbook instead of being presented as received zero.
- Blank receiving rows saved only to prepare/download Excel must remain `Pending` server-side; they must not be counted as `Short`/mismatch until a receiving quantity is actually entered.
- Upload must validate `SKU` against the currently selected PO.
- Upload must also validate that `SHIP QTY` still equals the selected PO quantity, so a workbook for a different/stale order cannot silently alter receiving data.
- User may fill `REC QTY` directly or use PAL-1..PAL-5. If both are supplied, REC QTY must equal the pallet sum.
- Import preview remains mandatory; invalid/unmatched rows are visible and are not silently discarded.
- `ORDER TOTAL` is ignored as an item row during import.

### Mandatory package checks

- Search UI/project files for `Download Format`, `DefaultFormat.ashx`, and `UnloadCompare_Default_Format.xlsx`; current project UI/runtime must not depend on them.
- Assert the `.csproj` contains no removed DefaultFormat/template paths.
- Assert Excel export and Excel import use the same approved header names.
- Assert import validates both SKU membership and SHIP QTY against the selected live PO.
- Assert left sidebar is present in `Site.Master`, current-page activation exists, and the mobile drawer has open/close behavior.



## Babco Unload Compare v1.2.0 - Header and Database Separation Rules

### Receiving header fields
- Persist `ContainerNumber`, `UnloadDate`, `UnloadBy1`, `UnloadBy2`, `UnloadBy3` in `UC_ReceivingHeader`.
- Draft/In Progress may be saved with these fields incomplete.
- Before `Ready for Verification`, require `UnloadDate` and `UnloadBy1`; keep `ContainerNumber` optional. `UnloadBy2` and `UnloadBy3` remain optional.
- Show the fields consistently on Main Receiving, Details, History, Print, and Audit output.
- Do not infer Unload By names from the current login; warehouse teams may include multiple people.

### Two-connection database boundary
- `UnloadCompareConnectionString` owns only the Unload Compare application schema (`UC_*`).
- `BabcoSupportConnectionString` is used for `UOS_Order`, `UOS_OrderDetail`, and `Item`.
- Never create or alter `UOS_Order`, `UOS_OrderDetail`, or `Item` from Unload Compare migration scripts.
- The support connection can be changed independently without moving receiving/audit/history data.
- For backward compatibility only, code may fall back to `ConnectionString` if either new named string is absent.
- SQL scripts `01_Schema.sql` and `02_StoredProcedures.sql` must run against the application DB and must not hard-code `USE [Babco]`.

### Production gap checklist
Recommended future additions: Dock/Door, unload start/end timestamps, seal number/photo, mismatch reason codes, separation of unloader/verifier, autosave, completed-record lock/reopen audit, Azure Blob document storage, database health diagnostics, role-based access, and operational monitoring.
