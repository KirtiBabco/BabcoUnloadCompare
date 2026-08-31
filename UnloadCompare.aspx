<%@ Page Title="Unload Compare" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="UnloadCompare.aspx.cs" Inherits="BabcoUnloadCompare.Web.UnloadCompare" %>
<asp:Content ID="t" ContentPlaceHolderID="TitleContent" runat="server">Unload Compare</asp:Content>
<asp:Content ID="m" ContentPlaceHolderID="MainContent" runat="server">
<section class="hero-row compact-hero"><div><span class="eyebrow">RECEIVING</span><h1>Unload Compare</h1><p>PO quantities vs. received / pallet counts.</p></div><div class="status-legend"><span class="pill matched">Matched</span><span class="pill short">Short</span><span class="pill over">Over</span></div></section>
<section class="card search-card compact-card"><div class="field grow"><label>PO Number</label><div class="search-line"><input id="poSearch" class="input input-lg" placeholder="Type PackingSlip number or vendor" autocomplete="off" role="combobox" aria-autocomplete="list" aria-controls="poResults" aria-expanded="false"/><button type="button" id="poDropdownBtn" class="btn" title="Show recent PackingSlips" aria-label="Show recent PackingSlips" onclick="UC.togglePOList()">▼</button><button type="button" id="searchPoBtn" class="btn primary" onclick="UC.searchPO()">Search PO</button></div><div id="poResults" class="search-results hidden" role="listbox"></div><small class="muted">Type to filter, choose from the dropdown, or enter the full PackingSlip and press Search.</small></div><div class="workflow"><span class="active">1 PO</span><i>→</i><span>2 Count</span><i>→</i><span>3 Verify</span><i>→</i><span>4 Complete</span></div></section>
<section id="receivingSection" class="hidden">
  <section class="card po-summary compact-summary unload-header-grid">
    <div><label>PO</label><strong id="sumPO">—</strong></div>
    <div><label>Vendor</label><strong id="sumVendor">—</strong></div>
    <div class="field"><label>Container Number</label><input id="containerNumber" class="input compact" maxlength="100" placeholder="Container #"/></div>
    <div class="field"><label>Receiving Date</label><input id="receivingDate" type="date" class="input compact"/></div>
    <div class="field"><label>Unload Date <span class="req">*</span></label><input id="unloadDate" type="date" class="input compact"/></div>
    <div class="field"><label>Unload By 1 <span class="req">*</span></label><input id="unloadBy1" class="input compact" maxlength="150" placeholder="Name"/></div>
    <div class="field"><label>Unload By 2</label><input id="unloadBy2" class="input compact" maxlength="150" placeholder="Name"/></div>
    <div class="field"><label>Unload By 3</label><input id="unloadBy3" class="input compact" maxlength="150" placeholder="Name"/></div>
    <div><label>Status</label><span id="recordStatus" class="pill draft">Draft</span></div>
  </section>
  <section class="toolbar card compact-toolbar"><div class="toolbar-group"><button type="button" class="btn excel-download" onclick="UC.exportExcel()">Download Excel</button><button type="button" class="btn" onclick="UC.uploadExcel()">Upload Filled Excel</button><input type="file" id="excelFile" accept=".xls,.xlsx" hidden/><button type="button" class="btn" onclick="UC.uploadDocument()">Upload Scan / PDF</button><input type="file" id="docFile" accept=".pdf,.jpg,.jpeg,.png,.webp" hidden/></div><div class="toolbar-group"><button type="button" class="btn" onclick="UC.save('In Progress')">Save</button><button type="button" class="btn success" onclick="UC.save('Ready for Verification')">Ready to Verify</button><button type="button" class="btn" onclick="UC.printReport()">Print</button></div></section>
  <section class="card compact-card"><div class="metric-strip"><span><b>Excel</b> Download → fill → upload → validate</span><span><b>Paper</b> Print → fill → scan PDF/image → AI preview</span><span><b>Safety</b> Review matched values before Apply</span></div></section>
  <section class="card grid-card receiving-grid-card">
    <div class="grid-head compact-grid-head">
      <div class="grid-title"><h2>PO Items</h2><p id="gridHint">REC QTY directly या PAL-1 to PAL-5 भरें. Excel workflow: Download → fill → Upload.</p><span class="mobile-grid-hint">Swipe horizontally to edit all columns.</span></div>
      <div class="grid-controls"><div class="metric-strip"><span><b id="itemCount">0</b> items</span><span><b id="matchCount">0</b> matched</span><span><b id="mismatchCount">0</b> mismatched</span></div><label class="page-size-control">Rows <select id="pageSize" class="input compact" onchange="UC.changePageSize(this.value)"><option value="10">10</option><option value="15" selected>15</option><option value="25">25</option><option value="50">50</option></select></label></div>
    </div>
    <div class="table-wrap receiving-table-wrap"><table id="itemGrid" class="receiving-table"><thead id="gridHead"></thead><tbody id="gridBody"></tbody><tfoot id="gridFoot"></tfoot></table></div>
    <div id="gridPager" class="grid-pager"></div>
  </section>
  <section class="card notes-card compact-notes"><div class="field grow"><label>Receiving Notes</label><textarea id="headerNotes" class="input" rows="2" placeholder="Optional receiving notes"></textarea></div><div id="uploadList" class="upload-list"><label>Uploaded receiving sheets</label><div class="muted">No documents uploaded yet.</div></div></section>
</section>
<div id="importModal" class="modal hidden"><div class="modal-box wide"><div class="modal-head"><div><span class="eyebrow" id="importSourceLabel">RECEIVING SHEET IMPORT PREVIEW</span><h3>Review before applying</h3></div><button type="button" class="icon-btn" onclick="UC.closeImport()">×</button></div><div id="importSummary"></div><div class="table-wrap"><table><thead><tr><th>Row</th><th>SKU</th><th>Item</th><th>Qty</th><th>Result</th></tr></thead><tbody id="importRows"></tbody></table></div><div class="modal-actions"><span class="muted">Unmatched or uncertain rows are never silently applied.</span><button type="button" class="btn primary" id="applyImportBtn" onclick="UC.applyImport()">Apply matched rows</button></div></div></div>
<div id="toast" class="toast hidden"></div>
</asp:Content>
<asp:Content ID="s" ContentPlaceHolderID="ScriptContent" runat="server"><script src="Scripts/unload-compare.js?v=1.3.0"></script></asp:Content>
