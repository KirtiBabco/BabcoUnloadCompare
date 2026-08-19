using System;
using System.Web;
using BabcoUnloadCompare.Web.Services;

namespace BabcoUnloadCompare.Web
{
    public class Global : HttpApplication
    {
        protected void Application_Start(object sender, EventArgs e)
        {
            DatabaseBootstrapper.EnsureAzureSchema();
        }
    }
}
