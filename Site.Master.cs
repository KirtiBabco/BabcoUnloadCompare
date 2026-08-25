using System;
using System.Linq;
using System.Web;

namespace BabcoUnloadCompare.Web
{
    public partial class SiteMaster : System.Web.UI.MasterPage
    {
        public string DisplayName { get; private set; } = "Warehouse User";
        public string UserInitials { get; private set; } = "WU";
        public string AuthenticationLabel { get; private set; } = "Receiving";
        public bool ShowSignOut { get; private set; }

        protected void Page_Load(object sender, EventArgs e)
        {
            var request = HttpContext.Current.Request;
            var isLocal = request.IsLocal ||
                          string.Equals(request.Url.Host, "localhost", StringComparison.OrdinalIgnoreCase) ||
                          string.Equals(request.Url.Host, "127.0.0.1", StringComparison.OrdinalIgnoreCase);

            var entraName = request.Headers["X-MS-CLIENT-PRINCIPAL-NAME"];
            var identityName = Context.User != null && Context.User.Identity != null && Context.User.Identity.IsAuthenticated
                ? Context.User.Identity.Name
                : null;

            if (!isLocal && string.IsNullOrWhiteSpace(entraName) && string.IsNullOrWhiteSpace(identityName))
            {
                var returnPath = string.IsNullOrWhiteSpace(request.RawUrl) ? "/UnloadCompare.aspx" : request.RawUrl;
                var loginUrl = "/.auth/login/aad?post_login_redirect_uri=" + HttpUtility.UrlEncode(returnPath);
                Response.Redirect(loginUrl, true);
                return;
            }

            if (isLocal && string.IsNullOrWhiteSpace(entraName) && string.IsNullOrWhiteSpace(identityName))
            {
                DisplayName = "Local Developer";
                UserInitials = "LD";
                AuthenticationLabel = "Local test mode";
                ShowSignOut = false;
                return;
            }

            DisplayName = !string.IsNullOrWhiteSpace(entraName) ? entraName : identityName;
            UserInitials = BuildInitials(DisplayName);
            AuthenticationLabel = "Microsoft Entra ID";
            ShowSignOut = true;
        }

        private static string BuildInitials(string value)
        {
            if (string.IsNullOrWhiteSpace(value)) return "WU";
            var clean = value.Split('@')[0].Replace('.', ' ').Replace('_', ' ').Replace('-', ' ');
            var parts = clean.Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
            if (parts.Length == 0) return "WU";
            if (parts.Length == 1) return parts[0].Substring(0, Math.Min(2, parts[0].Length)).ToUpperInvariant();
            return string.Concat(parts.Take(2).Select(p => char.ToUpperInvariant(p[0])));
        }
    }
}
