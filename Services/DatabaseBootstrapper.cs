using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.IO;
using System.Text.RegularExpressions;
using System.Web;

namespace BabcoUnloadCompare.Web.Services
{
    internal static class DatabaseBootstrapper
    {
        private static readonly object Sync = new object();
        private static bool _initialized;

        public static void EnsureAzureSchema()
        {
            if (_initialized) return;
            lock (Sync)
            {
                if (_initialized) return;
                var appCs = ConnectionStringResolver.GetRequired("UnloadCompareConnectionString");
                var supportCs = ConnectionStringResolver.GetRequired("BabcoSupportConnectionString");
                var basePath = HttpRuntime.AppDomainAppPath;
                if (string.IsNullOrWhiteSpace(basePath)) return;
                EnsureLocalApplicationDatabase(appCs);
                var scripts = new List<string>();
                if (PointsToSameDatabase(appCs, supportCs)) scripts.Add("00_AzureSupportPlaceholder.sql");
                scripts.Add("01_Schema.sql");
                scripts.Add("08_v1.2.0_Header_Upgrade.sql");
                scripts.Add("02_StoredProcedures.sql");
                using (var cn = new SqlConnection(appCs))
                {
                    cn.Open();
                    foreach (var file in scripts)
                    {
                        var path = Path.Combine(basePath, "App_Data", "Database", file);
                        if (!File.Exists(path)) throw new FileNotFoundException("Required database bootstrap script was not deployed.", path);
                        ExecuteBatches(cn, File.ReadAllText(path));
                    }
                    using (var cmd = new SqlCommand(@"IF OBJECT_ID('dbo.UC_SchemaVersion','U') IS NULL
CREATE TABLE dbo.UC_SchemaVersion(VersionNo nvarchar(30) NOT NULL PRIMARY KEY, AppliedDate datetime2 NOT NULL CONSTRAINT DF_UC_SchemaVersion_Applied DEFAULT(sysdatetime()));
IF NOT EXISTS(SELECT 1 FROM dbo.UC_SchemaVersion WHERE VersionNo='1.2.2')
INSERT dbo.UC_SchemaVersion(VersionNo) VALUES('1.2.2');", cn))
                    { cmd.CommandTimeout = 300; cmd.ExecuteNonQuery(); }
                }
                _initialized = true;
            }
        }

        private static void EnsureLocalApplicationDatabase(string connectionString)
        {
            var builder = new SqlConnectionStringBuilder(connectionString);
            var dataSource = builder.DataSource ?? string.Empty;
            var database = builder.InitialCatalog ?? string.Empty;
            if (string.IsNullOrWhiteSpace(database) || string.Equals(database, "master", StringComparison.OrdinalIgnoreCase) || IsAzureSql(dataSource)) return;
            var masterBuilder = new SqlConnectionStringBuilder(connectionString) { InitialCatalog = "master" };
            using (var cn = new SqlConnection(masterBuilder.ConnectionString))
            {
                cn.Open();
                using (var cmd = new SqlCommand(@"IF DB_ID(@DatabaseName) IS NULL
BEGIN
    DECLARE @Sql nvarchar(max) = N'CREATE DATABASE ' + QUOTENAME(@DatabaseName) + N';';
    EXEC sys.sp_executesql @Sql;
END", cn))
                { cmd.CommandTimeout = 300; cmd.Parameters.AddWithValue("@DatabaseName", database); cmd.ExecuteNonQuery(); }
            }
        }

        private static bool IsAzureSql(string dataSource) { return !string.IsNullOrWhiteSpace(dataSource) && dataSource.IndexOf(".database.windows.net", StringComparison.OrdinalIgnoreCase) >= 0; }
        private static bool PointsToSameDatabase(string first, string second)
        {
            try
            {
                var a = new SqlConnectionStringBuilder(first); var b = new SqlConnectionStringBuilder(second);
                return string.Equals((a.DataSource ?? "").Trim(), (b.DataSource ?? "").Trim(), StringComparison.OrdinalIgnoreCase) && string.Equals((a.InitialCatalog ?? "").Trim(), (b.InitialCatalog ?? "").Trim(), StringComparison.OrdinalIgnoreCase);
            }
            catch { return false; }
        }

        private static void ExecuteBatches(SqlConnection cn, string script)
        {
            foreach (var batch in Regex.Split(script ?? "", @"^\s*GO\s*(?:--.*)?$", RegexOptions.Multiline | RegexOptions.IgnoreCase))
            {
                if (string.IsNullOrWhiteSpace(batch)) continue;
                using (var cmd = new SqlCommand(batch, cn)) { cmd.CommandTimeout = 300; cmd.ExecuteNonQuery(); }
            }
        }
    }
}