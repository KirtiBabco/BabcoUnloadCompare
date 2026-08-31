using System;
using System.Data.SqlClient;
using System.Web.Services;
using BabcoUnloadCompare.Web.Models;
using BabcoUnloadCompare.Web.Services;
namespace BabcoUnloadCompare.Web
{
 public partial class UnloadCompare:System.Web.UI.Page
 {
  public const string AppVersion="1.3.0";
  protected void Page_Load(object sender,EventArgs e){if(Session["UserName"]==null)Session["UserName"]="Warehouse User";}
  [WebMethod] public static ApiResult<object> SearchPO(string query){try{return new ApiResult<object>{IsSuccess=true,Data=new DataAccess().SearchPO(query??"")};}catch(Exception ex){return Fail(ex);}}
  [WebMethod] public static ApiResult<object> LoadPO(string poNumber){try{var d=new DataAccess().LoadPO(poNumber);return d==null?new ApiResult<object>{IsSuccess=false,Message="PO was not found."}:new ApiResult<object>{IsSuccess=true,Data=d};}catch(Exception ex){return Fail(ex);}}
  [WebMethod] public static ApiResult<object> EnsureDraft(string poNumber){try{return new ApiResult<object>{IsSuccess=true,Data=new{ReceivingId=new DataAccess().EnsureDraft(poNumber)}};}catch(Exception ex){return Fail(ex);}}
  [WebMethod] public static ApiResult<object> LoadReceiving(int receivingId){try{var d=new DataAccess().GetDetails(receivingId);return d==null?new ApiResult<object>{IsSuccess=false,Message="Receiving record was not found."}:new ApiResult<object>{IsSuccess=true,Data=d};}catch(Exception ex){return Fail(ex);}}
  [WebMethod] public static ApiResult<object> SaveReceiving(ReceivingSaveRequest request){try{return new ApiResult<object>{IsSuccess=true,Message="Receiving record saved.",Data=new DataAccess().SaveReceiving(request)};}catch(Exception ex){return Fail(ex);}}
  [WebMethod]
  public static ApiResult<object> SaveFeedback(string type,int rating,string comments,string pageUrl)
  {
   try
   {
    type=(type??"").Trim(); comments=(comments??"").Trim(); pageUrl=(pageUrl??"").Trim();
    if(string.IsNullOrWhiteSpace(type))type="General";
    if(rating<1||rating>5)throw new InvalidOperationException("Rating must be between 1 and 5.");
    if(string.IsNullOrWhiteSpace(comments))throw new InvalidOperationException("Please enter feedback comments.");
    if(comments.Length>4000)comments=comments.Substring(0,4000);
    if(pageUrl.Length>1000)pageUrl=pageUrl.Substring(0,1000);
    using(var cn=new SqlConnection(ConnectionStringResolver.GetRequired("UnloadCompareConnectionString")))
    {
     cn.Open();
     using(var cmd=new SqlCommand(@"IF OBJECT_ID('dbo.UC_Feedback','U') IS NULL
BEGIN
 CREATE TABLE dbo.UC_Feedback(
  FeedbackId int IDENTITY(1,1) NOT NULL PRIMARY KEY,
  FeedbackType nvarchar(50) NOT NULL,
  Rating int NOT NULL,
  Comments nvarchar(4000) NOT NULL,
  PageUrl nvarchar(1000) NULL,
  AppVersion nvarchar(30) NOT NULL,
  SubmittedBy nvarchar(150) NOT NULL,
  SubmittedDate datetime2 NOT NULL CONSTRAINT DF_UC_Feedback_Date DEFAULT(sysdatetime())
 );
END;
INSERT dbo.UC_Feedback(FeedbackType,Rating,Comments,PageUrl,AppVersion,SubmittedBy)
VALUES(@Type,@Rating,@Comments,@PageUrl,@AppVersion,@SubmittedBy);",cn))
     {
      cmd.CommandTimeout=60;
      cmd.Parameters.AddWithValue("@Type",type);
      cmd.Parameters.AddWithValue("@Rating",rating);
      cmd.Parameters.AddWithValue("@Comments",comments);
      cmd.Parameters.AddWithValue("@PageUrl",string.IsNullOrWhiteSpace(pageUrl)?(object)DBNull.Value:pageUrl);
      cmd.Parameters.AddWithValue("@AppVersion",AppVersion);
      cmd.Parameters.AddWithValue("@SubmittedBy",AuthContext.CurrentUser);
      cmd.ExecuteNonQuery();
     }
    }
    return new ApiResult<object>{IsSuccess=true,Message="Thank you. Feedback saved for version "+AppVersion+".",Data=new{Version=AppVersion}};
   }
   catch(Exception ex){return Fail(ex);}
  }
  private static ApiResult<object> Fail(Exception ex){return new ApiResult<object>{IsSuccess=false,Message=ex.Message};}
 }
}
