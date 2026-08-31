using System;
using System.Collections.Generic;
using System.Configuration;
using System.IO;
using System.Linq;
using System.Web;
namespace BabcoUnloadCompare.Web.Services
{
    public static class UploadSecurity
    {
        public static readonly string[] ExcelExt = { ".xls", ".xlsx" };
        public static readonly string[] DocumentExt = { ".pdf", ".jpg", ".jpeg", ".png", ".webp" };
        public static string SafeFileName(string fileName) { return Path.GetFileName(fileName ?? "upload").Replace("..", "_").Replace("\r", "_").Replace("\n", "_").Replace("\"", "_"); }
        public static void Validate(HttpPostedFile file, IEnumerable<string> allowed)
        {
            if (file == null || file.ContentLength <= 0) throw new InvalidOperationException("Please select a file.");
            var maxMb = 15; int.TryParse(ConfigurationManager.AppSettings["UnloadCompare.MaxUploadMB"], out maxMb); if (maxMb <= 0) maxMb = 15;
            if (file.ContentLength > maxMb * 1024 * 1024) throw new InvalidOperationException("File exceeds the " + maxMb + " MB limit.");
            var ext = Path.GetExtension(file.FileName ?? "").ToLowerInvariant();
            if (!allowed.Contains(ext)) throw new InvalidOperationException("Unsupported file type: " + ext);
        }
    }
}
