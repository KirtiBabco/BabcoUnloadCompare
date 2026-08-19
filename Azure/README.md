# Azure App Service deployment - Babco Unload Compare v1.2.2

Runtime target: Windows Azure App Service (.NET Framework 4.7.2) + Azure SQL.

Application database settings:
- `UnloadCompareConnectionString` - application-owned `UC_*` schema.
- `BabcoSupportConnectionString` - live Babco source (`UOS_Order`, `UOS_OrderDetail`, `Item`).

Azure App Service settings override the local Windows Integrated Security fallbacks in `Web.config`. The application accepts exact App Settings names plus the App Service `SQLCONNSTR_` / `CUSTOMCONNSTR_` environment prefixes.

For first deployment both logical connections may point to the new Azure SQL database so the site can start with compatibility source tables. Later change only `BabcoSupportConnectionString` to the live private Babco SQL endpoint through Hybrid Connection; no code redeploy is required.

`DatabaseBootstrapper` applies the additive scripts from `App_Data/Database` and records schema version `1.2.2`.

The GitHub workflow builds on Windows with NuGet + MSBuild. Deployment to Azure is enabled only on a push to `main` after the Azure OIDC secrets and `AZURE_WEBAPP_NAME` repository variable are configured.