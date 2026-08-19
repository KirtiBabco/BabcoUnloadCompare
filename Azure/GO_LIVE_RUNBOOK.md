# BabcoUnloadCompare Azure go-live

Target: GitHub `main` -> GitHub Actions -> Windows Azure App Service; `UnloadCompareConnectionString` -> Azure SQL; `BabcoSupportConnectionString` -> private Babco SQL through Hybrid Connection; Microsoft Entra ID -> App Service Authentication.

## Order
1. Validate the PR build on Windows MSBuild.
2. Confirm Azure subscription, resource group, Windows App Service plan and region.
3. Deploy the sanitized `Azure/arm-template.json` with secure parameters entered only in Azure.
4. Confirm the Web App and `BabcoUnloadCompareDb` exist.
5. Configure GitHub OIDC values (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`) and repository variable `AZURE_WEBAPP_NAME`.
6. Merge to `main`; GitHub Actions builds and deploys.
7. Enable App Service Authentication with Microsoft / current workforce tenant / single tenant / require authentication.
8. Configure App Service Hybrid Connection to the live Babco SQL hostname and fixed TCP port.
9. Set only `BabcoSupportConnectionString` to the live Babco database credential in Azure configuration; never commit that password.
10. Smoke test Microsoft sign-in, known PO search, save, upload/download, export, history/details/print.

Do not put Azure, SQL or Microsoft passwords in GitHub files or chat.