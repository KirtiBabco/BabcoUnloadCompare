using System;
using System.Configuration;

namespace BabcoUnloadCompare.Web.Services
{
    internal static class ConnectionStringResolver
    {
        public static string GetRequired(string name)
        {
            var value = Environment.GetEnvironmentVariable(name);
            if (string.IsNullOrWhiteSpace(value)) value = Environment.GetEnvironmentVariable("APPSETTING_" + name);
            if (string.IsNullOrWhiteSpace(value)) value = Environment.GetEnvironmentVariable("SQLCONNSTR_" + name);
            if (string.IsNullOrWhiteSpace(value)) value = Environment.GetEnvironmentVariable("CUSTOMCONNSTR_" + name);
            if (!string.IsNullOrWhiteSpace(value)) return value.Trim();
            var configured = ConfigurationManager.ConnectionStrings[name];
            if (configured != null && !string.IsNullOrWhiteSpace(configured.ConnectionString)) return configured.ConnectionString.Trim();
            throw new ConfigurationErrorsException("Missing required database setting '" + name + "'. Configure it in Web.config locally or in Azure App Service settings.");
        }
    }
}