using System;
using System.Configuration;
using System.Data.SqlClient;

namespace BabcoUnloadCompare.Web.Services
{
    internal static class ConnectionStringResolver
    {
        public static string GetRequired(string name)
        {
            string source;
            var value = ReadAzureValue(name, out source);
            if (!string.IsNullOrWhiteSpace(value))
                return NormalizeAndValidate(name, value, source);

            var configured = ConfigurationManager.ConnectionStrings[name];
            if (configured != null && !string.IsNullOrWhiteSpace(configured.ConnectionString))
                return NormalizeAndValidate(name, configured.ConnectionString, "Web.config");

            throw new ConfigurationErrorsException(
                "Missing required database setting '" + name +
                "'. Configure it in Azure App Service > Settings > Environment variables > Connection strings.");
        }

        private static string ReadAzureValue(string name, out string source)
        {
            var candidates = new[]
            {
                "SQLCONNSTR_" + name,
                "SQLAZURECONNSTR_" + name,
                "CUSTOMCONNSTR_" + name,
                name,
                "APPSETTING_" + name
            };

            foreach (var key in candidates)
            {
                var value = Environment.GetEnvironmentVariable(key);
                if (!string.IsNullOrWhiteSpace(value))
                {
                    source = key;
                    return value;
                }
            }

            source = null;
            return null;
        }

        private static string NormalizeAndValidate(string name, string rawValue, string source)
        {
            var value = (rawValue ?? string.Empty).Trim();

            // Azure Portal values are sometimes pasted with surrounding quotes.
            // SqlClient treats the first quote as invalid connection-string syntax.
            if (value.Length >= 2 &&
                ((value[0] == '"' && value[value.Length - 1] == '"') ||
                 (value[0] == '\'' && value[value.Length - 1] == '\'')))
            {
                value = value.Substring(1, value.Length - 2).Trim();
            }

            // Also tolerate accidentally pasting "Name=<connection string>" into the Value box.
            var wrappers = new[]
            {
                name + "=",
                "SQLCONNSTR_" + name + "=",
                "SQLAZURECONNSTR_" + name + "=",
                "CUSTOMCONNSTR_" + name + "=",
                "APPSETTING_" + name + "="
            };
            foreach (var wrapper in wrappers)
            {
                if (value.StartsWith(wrapper, StringComparison.OrdinalIgnoreCase))
                {
                    value = value.Substring(wrapper.Length).Trim();
                    break;
                }
            }

            if (value.StartsWith("@Microsoft.KeyVault(", StringComparison.OrdinalIgnoreCase))
            {
                throw new ConfigurationErrorsException(
                    "Database setting '" + name + "' is an unresolved Azure Key Vault reference. " +
                    "Verify the Key Vault reference status and App Service managed-identity access.");
            }

            if (value.StartsWith("{") || value.StartsWith("["))
            {
                throw new ConfigurationErrorsException(
                    "Database setting '" + name + "' contains JSON instead of a SQL connection string. " +
                    "In Azure Connection strings, paste only the raw value beginning with Server= or Data Source=.");
            }

            try
            {
                var builder = new SqlConnectionStringBuilder(value);
                if (string.IsNullOrWhiteSpace(builder.DataSource))
                {
                    throw new ConfigurationErrorsException(
                        "Database setting '" + name + "' has no Server/Data Source. " +
                        "Check Azure App Service > Environment variables > Connection strings.");
                }
                return builder.ConnectionString;
            }
            catch (ConfigurationErrorsException)
            {
                throw;
            }
            catch (Exception ex)
            {
                throw new ConfigurationErrorsException(
                    "Database setting '" + name + "' from '" + (source ?? "configuration") +
                    "' is not a valid SQL Server connection string. " +
                    "Use raw syntax such as Server=HOST,PORT;Initial Catalog=DB;User ID=...;Password=...; " +
                    "Do not wrap the full value in quotes or JSON.", ex);
            }
        }
    }
}
