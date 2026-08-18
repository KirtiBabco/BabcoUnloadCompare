using System;
using System.Web.Services;
using BabcoUnloadCompare.Web.Models;
using BabcoUnloadCompare.Web.Services;
namespace BabcoUnloadCompare.Web
{
 public partial class UnloadCompare:System.Web.UI.Page
 {
  protected void Page_Load(object sender,EventArgs e){if(Session["UserName"]==null)Session["UserName"]="Warehouse User";}
  [WebMethod] public static ApiResult<object> SearchPO(string query){try{return new ApiResult<object>{IsSuccess=true,Data=new DataAccess().SearchPO(query??"")};}catch(Exception ex){return Fail(ex);}}
  [WebMethod] public static ApiResult<object> LoadPO(string poNumber){try{var d=new DataAccess().LoadPO(poNumber);return d==null?new ApiResult<object>{IsSuccess=false,Message="PO was not found."}:new ApiResult<object>{IsSuccess=true,Data=d};}catch(Exception ex){return Fail(ex);}}
  [WebMethod] public static ApiResult<object> EnsureDraft(string poNumber){try{return new ApiResult<object>{IsSuccess=true,Data=new{ReceivingId=new DataAccess().EnsureDraft(poNumber)}};}catch(Exception ex){return Fail(ex);}}
  [WebMethod] public static ApiResult<object> LoadReceiving(int receivingId){try{var d=new DataAccess().GetDetails(receivingId);return d==null?new ApiResult<object>{IsSuccess=false,Message="Receiving record was not found."}:new ApiResult<object>{IsSuccess=true,Data=d};}catch(Exception ex){return Fail(ex);}}
  [WebMethod] public static ApiResult<object> SaveReceiving(ReceivingSaveRequest request){try{return new ApiResult<object>{IsSuccess=true,Message="Receiving record saved.",Data=new DataAccess().SaveReceiving(request)};}catch(Exception ex){return Fail(ex);}}
  private static ApiResult<object> Fail(Exception ex){return new ApiResult<object>{IsSuccess=false,Message=ex.Message};}
 }
}
