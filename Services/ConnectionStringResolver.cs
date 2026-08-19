using System;
using System.Configuration;

namespace BabcoUnloadCompare.Web.Services
{
    internal static class ConnectionStringResolver
    {
        public static string GetRequired(string name)
        {
            // Azure App Service Connection Strings are exposed to .NET as
            // SQLCONNSTR_<name> / SQLAZURECONNSTR_<name> / CUSTOMCONNSTR_<name>.
            // Prefer these secret-managed values over ordinary App Settings so a
            // stale APPSETTING_<name> can never override the production DB secret.
            var value = Environment.GetEnvironmentVariable("SQLCONNSTR_" + name);
            if (string.IsNullOrWhiteSpace(value)) value = Environment.GetEnvironmentVariable("SQLAZURECONNSTR_" + name);
            if (string.IsNullOrWhiteSpace(value)) value = Environment.GetEnvironmentVariable("CUSTOMCONNSTR_" + name);
            if (string.IsNullOrWhiteSpace(value)) value = Environment.GetEnvironmentVariable(name);
            if (string.IsNullOrWhiteSpace(value)) value = Environment.GetEnvironmentVariable("APPSETTING_" + name);
            if (!string.IsNullOrWhiteSpace(value)) return value.Trim();

            var configured = ConfigurationManager.ConnectionStrings[name];
            if (configured != null && !string.IsNullOrWhiteSpace(configured.ConnectionString))
                return configured.ConnectionString.Trim();

            throw new ConfigurationErrorsException(
                "Missing required database setting '" + name +
                "'. Configure it in Web.config locally or in Azure App Service Environment variables > Connection strings.");
        }
    }
}
