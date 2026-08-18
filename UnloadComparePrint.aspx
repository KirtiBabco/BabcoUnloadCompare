<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="UnloadComparePrint.aspx.cs" Inherits="BabcoUnloadCompare.Web.UnloadComparePrint" %>
<!DOCTYPE html>
<html>
<head runat="server">
<meta charset="utf-8"/>
<title>Unload Comparison Report</title>
<style>
body{font-family:Segoe UI,Arial;margin:20px;color:#222}h1{margin:0 0 6px;color:#7f1d2d}.meta{display:grid;grid-template-columns:repeat(4,1fr);gap:8px;margin:14px 0}.meta div{border:1px solid #ddd;padding:7px}.meta small{display:block;color:#666}table{width:100%;border-collapse:collapse;font-size:10px}th,td{border-bottom:1px solid #ccc;padding:5px;text-align:left;vertical-align:top}th{background:#7f1d2d;color:#fff;white-space:nowrap}.right{text-align:right}.total-row td{background:#f1eee7;border-top:2px solid #7f1d2d}.verify{margin-top:16px;border-top:1px solid #999;padding-top:10px}.no-print{margin-bottom:10px;padding:8px 12px}@page{size:landscape;margin:8mm}@media print{.no-print{display:none}body{margin:0}}
</style>
</head>
<body>
<form runat="server">
<button type="button" class="no-print" onclick="window.print()">Print</button>
<h1>Babco Foods - Unload Comparison Report</h1>
<asp:Literal ID="ReportHtml" runat="server" />
</form>
</body>
</html>
