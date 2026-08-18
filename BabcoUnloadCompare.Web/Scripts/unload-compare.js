var UC=(function(){
 var state={po:null,items:[],receivingId:null,status:'Draft',importPreview:null,docs:[],page:1,pageSize:15};
 function num(v){var n=parseFloat(v);return isNaN(n)?0:n;}
 function hasValue(v){return v!==null&&v!==undefined&&String(v).trim()!=='';}
 function palletTotal(x){return x.pallets.reduce(function(a,p){return a+(hasValue(p.quantity)?num(p.quantity):0);},0);}
 function hasPallet(x){return x.pallets.some(function(p){return hasValue(p.quantity);});}
 function calc(x){
   var entered=x.entryMode==='Pallet'?hasPallet(x):hasValue(x.manualPhysicalQty);
   var physical=x.entryMode==='Pallet'?palletTotal(x):(entered?num(x.manualPhysicalQty):null);
   x.totalPalletQty=hasPallet(x)?palletTotal(x):null;
   x.totalPhysicalQty=physical;
   x.differenceQty=entered?physical-num(x.expectedQty):null;
   x.compareStatus=!entered?'Pending':(x.differenceQty===0?'Matched':(x.differenceQty<0?'Short':'Over'));
   return x;
 }
 function maxP(){return 5;}
 function findPallet(x,no){return x.pallets.find(function(p){return p.palletNo===no;});}
 function setPallet(x,no,value){var p=findPallet(x,no);if(!p){p={palletNo:no,quantity:null};x.pallets.push(p);x.pallets.sort(function(a,b){return a.palletNo-b.palletNo;});}p.quantity=hasValue(value)?num(value):null;x.entryMode='Pallet';}
 function diffText(x){return x.differenceQty==null?'':((x.differenceQty>0?'+':'')+x.differenceQty);}
 function render(){
   var mp=maxP();
   var totalItems=state.items.length;
   var totalPages=Math.max(1,Math.ceil(totalItems/state.pageSize));
   if(state.page>totalPages)state.page=totalPages;
   if(state.page<1)state.page=1;
   var startIndex=(state.page-1)*state.pageSize;
   var endIndex=Math.min(totalItems,startIndex+state.pageSize);
   var h='<tr><th>SKU</th><th>PACKING</th><th>SHIP QTY</th><th>REC QTY</th><th>Expiry</th><th>Nitrogen</th><th>DIFF (+/-)</th>';
   for(var i=1;i<=mp;i++)h+='<th>PAL-'+i+'</th>';
   h+='<th>TOTAL</th><th>STATUS</th><th>NOTES</th></tr>';
   document.getElementById('gridHead').innerHTML=h;

   var b='';
   for(var idx=startIndex;idx<endIndex;idx++){
     var x=state.items[idx];
     calc(x);
     b+='<tr class="row-'+x.compareStatus.toLowerCase()+'">';
     b+='<td><strong>'+App.esc(x.sku)+'</strong></td>';
     b+='<td class="packing" title="'+App.esc(x.itemName)+'">'+App.esc(x.itemName)+'</td>';
     b+='<td class="num">'+x.expectedQty+'</td>';
     if(x.entryMode==='Pallet') b+='<td><input class="input qty readonly" value="'+(x.totalPhysicalQty==null?'':x.totalPhysicalQty)+'" readonly title="Calculated from PAL-1 to PAL-5"/></td>';
     else b+='<td><input class="input qty" type="number" min="0" step="0.01" value="'+(x.manualPhysicalQty==null?'':x.manualPhysicalQty)+'" onchange="UC.manual('+idx+',this.value)"/></td>';
     b+='<td><input class="input date-text" value="'+App.esc(x.expiryDate||'')+'" placeholder="Jun-28" onchange="UC.expiry('+idx+',this.value)"/></td>';
     b+='<td><input class="input nitrogen" value="'+App.esc(x.nitrogen||'')+'" onchange="UC.nitrogen('+idx+',this.value)"/></td>';
     b+='<td class="num diff">'+diffText(x)+'</td>';
     for(var pal=1;pal<=mp;pal++){
       var pv=findPallet(x,pal);
       b+='<td><input class="input qty pallet-cell" type="number" min="0" step="0.01" value="'+(pv&&hasValue(pv.quantity)?pv.quantity:'')+'" onchange="UC.palletCell('+idx+','+pal+',this.value)"/></td>';
     }
     b+='<td class="num total">'+(x.totalPalletQty==null?'':x.totalPalletQty)+'</td>';
     b+='<td><span class="pill '+x.compareStatus.toLowerCase()+'">'+x.compareStatus+'</span></td>';
     b+='<td><input class="input compact note-input" value="'+App.esc(x.notes||'')+'" onchange="UC.note('+idx+',this.value)"/></td></tr>';
   }
   if(!b)b='<tr><td colspan="15" class="empty">No PO items to display.</td></tr>';
   document.getElementById('gridBody').innerHTML=b;

   var shipTotal=0,recTotal=0,diffTotal=0,palletTotals=[0,0,0,0,0],palletGrand=0,enteredCount=0;
   state.items.forEach(function(x){
     calc(x);
     shipTotal+=num(x.expectedQty);
     if(x.totalPhysicalQty!==null&&x.totalPhysicalQty!==undefined){recTotal+=num(x.totalPhysicalQty);enteredCount++;}
     if(x.differenceQty!==null&&x.differenceQty!==undefined)diffTotal+=num(x.differenceQty);
     for(var pi=1;pi<=5;pi++){var pp=findPallet(x,pi);if(pp&&hasValue(pp.quantity))palletTotals[pi-1]+=num(pp.quantity);}
     if(x.totalPalletQty!==null&&x.totalPalletQty!==undefined)palletGrand+=num(x.totalPalletQty);
   });
   var allEntered=totalItems>0&&enteredCount===totalItems;
   var f='<tr class="grand-total"><td colspan="2" class="order-total-label">ORDER TOTAL</td><td class="num">'+fmtQty(shipTotal)+'</td><td class="num">'+fmtQty(recTotal)+'</td><td></td><td></td><td class="num diff">'+(allEntered?fmtSigned(diffTotal):'—')+'</td>';
   palletTotals.forEach(function(v){f+='<td class="num">'+(v?fmtQty(v):'')+'</td>';});
   f+='<td class="num">'+(palletGrand?fmtQty(palletGrand):'')+'</td><td colspan="2">'+enteredCount+'/'+totalItems+' entered</td></tr>';
   document.getElementById('gridFoot').innerHTML=f;

   var matched=state.items.filter(function(x){return calc(x).compareStatus==='Matched';}).length;
   var pending=state.items.filter(function(x){return calc(x).compareStatus==='Pending';}).length;
   document.getElementById('itemCount').textContent=totalItems;
   document.getElementById('matchCount').textContent=matched;
   document.getElementById('mismatchCount').textContent=totalItems-matched-pending;
   renderPager(totalPages,startIndex,endIndex,totalItems);
 }
 function fmtQty(v){var n=Number(v||0);return Math.abs(n-Math.round(n))<0.000001?String(Math.round(n)):n.toFixed(2).replace(/0+$/,'').replace(/\.$/,'');}
 function fmtSigned(v){return (v>0?'+':'')+fmtQty(v);}
 function renderPager(totalPages,startIndex,endIndex,totalItems){
   var pager=document.getElementById('gridPager');if(!pager)return;
   if(totalItems<=state.pageSize){pager.innerHTML='<span class="pager-info">Showing '+totalItems+' of '+totalItems+' items</span><span class="pager-info">Order totals shown above.</span>';return;}
   var buttons='<button class="pager-btn" type="button" onclick="UC.goPage('+(state.page-1)+')" '+(state.page<=1?'disabled':'')+'>‹ Prev</button>';
   var first=Math.max(1,state.page-2),last=Math.min(totalPages,first+4);first=Math.max(1,last-4);
   for(var p=first;p<=last;p++)buttons+='<button class="pager-btn '+(p===state.page?'active':'')+'" type="button" onclick="UC.goPage('+p+')">'+p+'</button>';
   buttons+='<button class="pager-btn" type="button" onclick="UC.goPage('+(state.page+1)+')" '+(state.page>=totalPages?'disabled':'')+'>Next ›</button>';
   pager.innerHTML='<span class="pager-info">Showing '+(startIndex+1)+'-'+endIndex+' of '+totalItems+' items</span><div class="pager-buttons">'+buttons+'</div>';
 }
 function payload(status){return {request:{ReceivingId:state.receivingId,PONumber:state.po.PONumber,VendorName:state.po.VendorName,ContainerNumber:document.getElementById('containerNumber').value.trim(),ReceivingDate:document.getElementById('receivingDate').value||null,UnloadDate:document.getElementById('unloadDate').value||null,UnloadBy1:document.getElementById('unloadBy1').value.trim(),UnloadBy2:document.getElementById('unloadBy2').value.trim(),UnloadBy3:document.getElementById('unloadBy3').value.trim(),Status:status,Notes:document.getElementById('headerNotes').value,Items:state.items.map(function(x){calc(x);return {ReceivingItemId:x.receivingItemId||null,SKU:x.sku,ItemName:x.itemName,ExpectedQty:x.expectedQty,UOM:x.uom,ExpectedPallets:x.expectedPallets,EntryMode:x.entryMode,ManualPhysicalQty:x.entryMode==='Manual'&&hasValue(x.manualPhysicalQty)?num(x.manualPhysicalQty):null,ExpiryDate:x.expiryDate||'',Nitrogen:x.nitrogen||'',Notes:x.notes||'',Pallets:x.entryMode==='Pallet'?x.pallets.filter(function(p){return hasValue(p.quantity);}).map(function(p){return {PalletId:p.palletId||null,PalletNo:p.palletNo,Quantity:num(p.quantity)};}):[]};})}};}
 function ensureDraft(){if(state.receivingId)return Promise.resolve(state.receivingId);return App.post('UnloadCompare.aspx','EnsureDraft',{poNumber:state.po.PONumber}).then(function(r){if(!r.IsSuccess)throw new Error(r.Message);state.receivingId=r.Data.ReceivingId;return state.receivingId;});}
 function itemFromSource(x){return {sku:x.SKU,itemName:x.ItemName,expectedQty:x.ExpectedQty,uom:x.UOM,expectedPallets:x.ExpectedPallets,entryMode:'Manual',manualPhysicalQty:null,expiryDate:'',nitrogen:'',pallets:[],notes:''};}
 function itemFromReceiving(x){return {receivingItemId:x.ReceivingItemId,sku:x.SKU,itemName:x.ItemName,expectedQty:x.ExpectedQty,uom:x.UOM,expectedPallets:x.ExpectedPallets,entryMode:x.EntryMode||'Manual',manualPhysicalQty:x.ManualPhysicalQty,expiryDate:x.ExpiryDate||'',nitrogen:x.Nitrogen||'',pallets:(x.Pallets||[]).filter(function(p){return p.PalletNo>=1&&p.PalletNo<=5;}).map(function(p){return {palletId:p.PalletId,palletNo:p.PalletNo,quantity:p.Quantity};}),notes:x.Notes||''};}
 function mergeReceivingWithLive(liveItems,savedItems){
   var saved={};
   (savedItems||[]).forEach(function(x){if(x.SKU)saved[String(x.SKU).trim().toLowerCase()]=itemFromReceiving(x);});
   return (liveItems||[]).map(function(src){
     var live=itemFromSource(src);
     var old=saved[String(live.sku||'').trim().toLowerCase()];
     if(!old)return live;
     old.itemName=live.itemName||old.itemName||'';
     old.expectedQty=live.expectedQty;
     old.uom=live.uom||old.uom||'';
     old.expectedPallets=live.expectedPallets;
     return old;
   });
 }
 var api={
  searchPO:function(){
    var input=document.getElementById('poSearch');
    var q=input.value.trim();
    if(!q){App.toast('Enter a PO number.',true);return;}
    var btn=document.getElementById('searchPoBtn');
    if(btn){btn.disabled=true;btn.textContent='Loading...';}
    return App.post('UnloadCompare.aspx','SearchPO',{query:q}).then(function(r){
      if(!r.IsSuccess)throw new Error(r.Message);
      var rows=r.Data||[];
      var box=document.getElementById('poResults');
      if(!rows.length){
        box.innerHTML='<div class="empty">No matching PO found in UOS_Order.</div>';
        box.classList.remove('hidden');
        return;
      }

      // Warehouse UX: Search PO must load the order, not force a second click.
      // Prefer an exact PO match; if the search returns only one row, load that row.
      var nq=q.toLowerCase();
      var exact=rows.find(function(x){return String(x.PONumber||'').trim().toLowerCase()===nq;});
      if(exact||rows.length===1){
        var chosen=exact||rows[0];
        input.value=chosen.PONumber;
        box.classList.add('hidden');
        return api.loadPO(chosen.PONumber);
      }

      box.innerHTML=rows.map(function(x){
        var po=encodeURIComponent(String(x.PONumber||'')).replace(/'/g,'%27');
        return '<button type="button" onclick="UC.selectPO(decodeURIComponent(\''+po+'\'))"><strong>'+App.esc(x.PONumber)+'</strong><span>'+App.esc(x.VendorName||'')+' · '+App.esc(x.ContainerNumber||'No container')+' · '+x.ItemCount+' items · Click to load</span></button>';
      }).join('');
      box.classList.remove('hidden');
    }).catch(function(e){App.toast(e.message,true);}).finally(function(){
      if(btn){btn.disabled=false;btn.textContent='Search PO';}
    });
  },
  selectPO:function(po){
    document.getElementById('poSearch').value=po;
    document.getElementById('poResults').classList.add('hidden');
    return api.loadPO(po);
  },
  loadPO:function(po){
    var input=document.getElementById('poSearch');
    input.value=po;
    document.getElementById('poResults').classList.add('hidden');
    App.toast('Loading '+po+' items...');
    return App.post('UnloadCompare.aspx','LoadPO',{poNumber:po}).then(function(r){
      if(!r.IsSuccess)throw new Error(r.Message);
      state.po=r.Data.Header;
      state.receivingId=r.Data.ExistingReceivingId||null;
      var liveItems=r.Data.Items||[];
      state.items=liveItems.map(itemFromSource);
      state.page=1;
      document.body.classList.add('po-loaded');
      document.getElementById('poResults').classList.add('hidden');
      document.getElementById('receivingSection').classList.remove('hidden');
      document.getElementById('sumPO').textContent=state.po.PONumber;
      document.getElementById('sumVendor').textContent=state.po.VendorName||'—';
      document.getElementById('containerNumber').value=state.po.ContainerNumber||'';
      document.getElementById('receivingDate').value=App.fmtDate(state.po.ReceivingDate)||new Date().toISOString().slice(0,10);
      document.getElementById('unloadDate').value=new Date().toISOString().slice(0,10);
      document.getElementById('unloadBy1').value=''; document.getElementById('unloadBy2').value=''; document.getElementById('unloadBy3').value='';
      render();
      document.getElementById('receivingSection').scrollIntoView({behavior:'smooth',block:'start'});

      if(!state.receivingId){
        if(!state.items.length)App.toast('PO found, but no rows were found in UOS_OrderDetail for this OrderId.',true);
        else App.toast(state.items.length+' PO items loaded for '+state.po.PONumber+'.');
        return;
      }

      App.post('UnloadCompare.aspx','LoadReceiving',{receivingId:state.receivingId}).then(function(er){
        if(!er.IsSuccess)throw new Error(er.Message);
        var d=er.Data;
        if(d.Header.Status==='Ready for Verification'||d.Header.Status==='Verified'||d.Header.Status==='Completed'){
          location.href='UnloadCompareDetails.aspx?id='+state.receivingId;
          return;
        }
        state.status=d.Header.Status;
        document.getElementById('recordStatus').textContent=state.status;
        document.getElementById('headerNotes').value=d.Header.Notes||'';
        document.getElementById('containerNumber').value=d.Header.ContainerNumber||document.getElementById('containerNumber').value;
        document.getElementById('receivingDate').value=App.fmtDate(d.Header.ReceivingDate)||document.getElementById('receivingDate').value;
        document.getElementById('unloadDate').value=App.fmtDate(d.Header.UnloadDate)||document.getElementById('unloadDate').value;
        document.getElementById('unloadBy1').value=d.Header.UnloadBy1||''; document.getElementById('unloadBy2').value=d.Header.UnloadBy2||''; document.getElementById('unloadBy3').value=d.Header.UnloadBy3||'';

        // Never replace a valid live PO item list with an empty/stale draft.
        // Merge saved receiving values onto the current live PO rows by SKU.
        state.items=mergeReceivingWithLive(liveItems,d.Items||[]);
        state.docs=d.Documents||[];
        render();
        document.getElementById('uploadList').innerHTML='<label>Uploaded receiving sheets</label>'+state.docs.map(function(doc){return '<div class="doc-row"><span>'+App.esc(doc.OriginalFileName)+'</span><span class="pill draft">'+App.esc(doc.ExtractionStatus)+'</span></div>';}).join('');
        App.toast(state.items.length+' PO items loaded; existing receiving draft merged by SKU.');
      }).catch(function(e){App.toast(e.message,true);});
    }).catch(function(e){App.toast(e.message,true);});
  },
  manual:function(i,v){state.items[i].entryMode='Manual';state.items[i].manualPhysicalQty=hasValue(v)?num(v):null;state.items[i].pallets=[];render();},
  expiry:function(i,v){state.items[i].expiryDate=v;},
  nitrogen:function(i,v){state.items[i].nitrogen=v;},
  note:function(i,v){state.items[i].notes=v;},
  palletCell:function(i,p,v){
    if(p<1||p>5)return;
    setPallet(state.items[i],p,v);
    state.items[i].manualPhysicalQty=null;
    render();
  },
  changePageSize:function(v){var n=parseInt(v,10);state.pageSize=(n===10||n===15||n===25||n===50)?n:15;state.page=1;render();},
  goPage:function(p){var totalPages=Math.max(1,Math.ceil(state.items.length/state.pageSize));state.page=Math.max(1,Math.min(totalPages,parseInt(p,10)||1));render();var wrap=document.querySelector('.receiving-table-wrap');if(wrap)wrap.scrollTop=0;},
  save:function(status){if(!state.po)return;if(status==='Ready for Verification'){if(!document.getElementById('unloadDate').value){App.toast('Unload Date is required before verification.',true);return;}if(!document.getElementById('unloadBy1').value.trim()){App.toast('Unload By 1 is required before verification.',true);return;}var pending=state.items.some(function(x){return calc(x).compareStatus==='Pending';});if(pending){App.toast('Enter REC QTY or pallet quantities for every item before verification.',true);return;}}App.post('UnloadCompare.aspx','SaveReceiving',payload(status)).then(function(r){if(!r.IsSuccess)throw new Error(r.Message);state.receivingId=r.Data.ReceivingId;state.status=r.Data.Status;document.getElementById('recordStatus').textContent=state.status;App.toast(r.Message);if(status==='Ready for Verification')location.href='UnloadCompareDetails.aspx?id='+state.receivingId;}).catch(function(e){App.toast(e.message,true);});},
  uploadExcel:function(){if(!state.po){App.toast('Select a PO first.',true);return;}App.toast('Upload the Excel downloaded for this PO after filling REC / Expiry / Nitrogen / PAL-1 to PAL-5.');document.getElementById('excelFile').click();},
  uploadDocument:function(){if(!state.po){App.toast('Select a PO first.',true);return;}document.getElementById('docFile').click();},
  closeImport:function(){document.getElementById('importModal').classList.add('hidden');},
  applyImport:function(){if(!state.importPreview)return;var hasExisting=state.importPreview.MatchedRows.some(function(r){var x=state.items.find(function(z){return z.sku.toLowerCase()===r.SKU.toLowerCase();});return x&&calc(x).compareStatus!=='Pending';});if(hasExisting&&!window.confirm('Applying the Excel import will replace current received/pallet quantities for matched SKUs. Continue?'))return;state.importPreview.MatchedRows.forEach(function(r){var x=state.items.find(function(z){return z.sku.toLowerCase()===r.SKU.toLowerCase();});if(x){var ps=(r.Pallets||[]).slice(0,5);var has=ps.some(function(v){return v!==null&&v!==undefined;});if(has){x.entryMode='Pallet';x.pallets=[];ps.forEach(function(v,i){if(v!==null&&v!==undefined)x.pallets.push({palletNo:i+1,quantity:v});});x.manualPhysicalQty=null;}else{x.entryMode='Manual';x.manualPhysicalQty=r.Quantity;}x.expiryDate=r.ExpiryDate||'';x.nitrogen=r.Nitrogen||'';}});UC.closeImport();render();App.toast('Filled Excel applied to matched PO rows. Review, then Save or Ready to Verify.');},
  exportExcel:function(){
    if(!state.po){App.toast('Select a PO first.',true);return;}
    var status=(state.status&&state.status!=='Ready for Verification'&&state.status!=='Verified'&&state.status!=='Completed')?state.status:'Draft';
    App.toast('Preparing Excel with current PO records...');
    App.post('UnloadCompare.aspx','SaveReceiving',payload(status)).then(function(r){
      if(!r.IsSuccess)throw new Error(r.Message);
      state.receivingId=r.Data.ReceivingId;
      state.status=r.Data.Status||status;
      document.getElementById('recordStatus').textContent=state.status;
      location.href='Handlers/ExcelExport.ashx?id='+state.receivingId+'&mode=fill';
    }).catch(function(e){App.toast(e.message,true);});
  },
  printReport:function(){if(!state.receivingId){App.toast('Save the receiving record before printing.',true);return;}window.open('UnloadComparePrint.aspx?id='+state.receivingId,'_blank');}
 };
 function bindFiles(){
   document.getElementById('excelFile').addEventListener('change',function(){var file=this.files[0];if(!file)return;ensureDraft().then(function(id){var fd=new FormData();fd.append('file',file);fd.append('poNumber',state.po.PONumber);fd.append('receivingId',id);return fetch('Handlers/ExcelImport.ashx',{method:'POST',body:fd});}).then(function(r){return r.json();}).then(function(x){if(!x.IsSuccess&&(!x.Data||!x.Data.MatchedRows))throw new Error(x.Message);state.importPreview=x.Data;var all=(x.Data.MatchedRows||[]).concat(x.Data.UnmatchedRows||[]);document.getElementById('importSummary').innerHTML='<div class="metric-strip"><span><b>'+x.Data.MatchedRows.length+'</b> matched</span><span><b>'+x.Data.UnmatchedRows.length+'</b> unmatched/error</span></div>';document.getElementById('importRows').innerHTML=all.map(function(r){return '<tr><td>'+r.RowNo+'</td><td>'+App.esc(r.SKU)+'</td><td>'+App.esc(r.ItemName)+'</td><td>'+((r.Quantity==null)?'—':r.Quantity)+'</td><td><span class="pill '+(r.IsMatched?'matched':'short')+'">'+(r.IsMatched?'Matched':App.esc(r.ValidationMessage))+'</span></td></tr>';}).join('');document.getElementById('importModal').classList.remove('hidden');}).catch(function(e){App.toast(e.message,true);});this.value='';});
   document.getElementById('docFile').addEventListener('change',function(){var file=this.files[0];if(!file)return;ensureDraft().then(function(id){var fd=new FormData();fd.append('file',file);fd.append('receivingId',id);return fetch('Handlers/DocumentUpload.ashx',{method:'POST',body:fd});}).then(function(r){return r.json();}).then(function(x){if(!x.IsSuccess)throw new Error(x.Message);state.docs.push(x.Data);document.getElementById('uploadList').innerHTML='<label>Uploaded receiving sheets</label>'+state.docs.map(function(d){return '<div class="doc-row"><span>'+App.esc(d.OriginalFileName)+'</span><span class="pill draft">'+App.esc(d.ExtractionStatus)+'</span></div>';}).join('');App.toast(x.Message);}).catch(function(e){App.toast(e.message,true);});this.value='';});
 }
 document.addEventListener('DOMContentLoaded',function(){bindFiles();document.getElementById('poSearch').addEventListener('keydown',function(e){if(e.key==='Enter'){e.preventDefault();api.searchPO();}});var po=App.qs('po');if(po){document.getElementById('poSearch').value=po;api.loadPO(po);}});
 return api;
})();
