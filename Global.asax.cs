using System;
using System.Diagnostics;
using System.Web;
using BabcoUnloadCompare.Web.Services;

namespace BabcoUnloadCompare.Web
{
    public class Global : HttpApplication
    {
        protected void Application_Start(object sender, EventArgs e)
        {
            // Production safety: database bootstrap must never take the whole web app down.
            // Azure SQL can be resuming, a secret can be temporarily invalid, or an external
            // Babco source can be unreachable. Log the bootstrap failure and allow IIS to
            // finish starting so the site remains available and the real DB error can be
            // surfaced at the operation that needs the database.
            try
            {
                DatabaseBootstrapper.EnsureAzureSchema();
            }
            catch (Exception ex)
            {
                Trace.TraceError("Database bootstrap failed during Application_Start: {0}", ex);
            }
        }
    }
}
