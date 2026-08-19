using System;
using System.Web;

namespace BabcoUnloadCompare.Web.Services
{
    internal static class AuthContext
    {
        public static string CurrentUser
        {
            get
            {
                var context = HttpContext.Current;
                if (context == null) return "Warehouse User";
                var principalName = context.Request.Headers["X-MS-CLIENT-PRINCIPAL-NAME"];
                if (!string.IsNullOrWhiteSpace(principalName)) return principalName.Trim();
                if (context.User != null && context.User.Identity != null && context.User.Identity.IsAuthenticated && !string.IsNullOrWhiteSpace(context.User.Identity.Name)) return context.User.Identity.Name.Trim();
                var sessionUser = context.Session == null ? null : context.Session["UserName"] as string;
                if (!string.IsNullOrWhiteSpace(sessionUser)) return sessionUser.Trim();
                return "Warehouse User";
            }
        }

        public static void EnsureSessionUser()
        {
            var context = HttpContext.Current;
            if (context == null || context.Session == null) return;
            context.Session["UserName"] = CurrentUser;
        }
    }
}