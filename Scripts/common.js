window.App={
 post:function(url,method,data){return fetch(url+'/'+method,{method:'POST',headers:{'Content-Type':'application/json; charset=utf-8'},body:JSON.stringify(data||{})}).then(function(r){if(!r.ok)throw new Error('Request failed');return r.json();}).then(function(x){return x.d;});},
 toast:function(msg,bad){var t=document.getElementById('toast');if(!t){alert(msg);return;}t.textContent=msg;t.className='toast '+(bad?'bad':'good');setTimeout(function(){t.className='toast hidden';},3400);},
 fmtDate:function(v){if(!v)return '';var m=/Date\((\d+)\)/.exec(v);var d=m?new Date(+m[1]):new Date(v);return isNaN(d.getTime())?'':d.toISOString().slice(0,10);},
 esc:function(s){return String(s==null?'':s).replace(/[&<>"']/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c];});},
 qs:function(k){return new URLSearchParams(location.search).get(k);},
 openSidebar:function(){document.body.classList.add('sidebar-open');},
 closeSidebar:function(){document.body.classList.remove('sidebar-open');},
 setActiveNav:function(){var file=(location.pathname.split('/').pop()||'Default.aspx').toLowerCase();if(file==='default.aspx'||file==='')file='unloadcompare.aspx';if(file==='unloadcomparedetails.aspx'||file==='unloadcompareprint.aspx')file='unloadcomparehistory.aspx';document.querySelectorAll('.side-nav-link').forEach(function(a){var target=(a.getAttribute('data-nav')||'').toLowerCase();a.classList.toggle('active',target===file);});}
};
document.addEventListener('DOMContentLoaded',function(){App.setActiveNav();});
