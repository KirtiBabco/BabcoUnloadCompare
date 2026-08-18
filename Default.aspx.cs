using System;

namespace BabcoUnloadCompare.Web
{
    public partial class Default : System.Web.UI.Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            Response.Redirect(ResolveUrl("~/UnloadCompare.aspx"), false);
            Context.ApplicationInstance.CompleteRequest();
        }
    }
}
