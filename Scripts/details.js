var UCD = (function () {
    var id = 0, d = null;

    function load() {
        id = parseInt(App.qs('id') || '0', 10);
        if (!id) { App.toast('Invalid receiving id.', true); return; }
        App.post('UnloadCompareDetails.aspx', 'GetDetails', { receivingId: id })
            .then(function (r) {
                if (!r.IsSuccess) throw new Error(r.Message);
                d = r.Data;
                render();
            })
            .catch(function (e) { App.toast(e.message, true); });
    }

    function render() {
        var h = d.Header;
        document.getElementById('detailTitle').textContent = 'PO ' + h.PONumber + ' - Unload Compare';
        document.getElementById('detailSummary').innerHTML =
            '<div><label>PO</label><strong>' + App.esc(h.PONumber) + '</strong></div>' +
            '<div><label>Vendor</label><strong>' + App.esc(h.VendorName) + '</strong></div>' +
            '<div><label>Container</label><strong>' + App.esc(h.ContainerNumber || '-') + '</strong></div>' +
            '<div><label>Receiving Date</label><strong>' + App.fmtDate(h.ReceivingDate) + '</strong></div>' +
            '<div><label>Unload Date</label><strong>' + App.fmtDate(h.UnloadDate) + '</strong></div>' +
            '<div><label>Unload By 1</label><strong>' + App.esc(h.UnloadBy1 || '-') + '</strong></div>' +
            '<div><label>Unload By 2</label><strong>' + App.esc(h.UnloadBy2 || '-') + '</strong></div>' +
            '<div><label>Unload By 3</label><strong>' + App.esc(h.UnloadBy3 || '-') + '</strong></div>' +
            '<div><label>Status</label><span class="pill draft">' + App.esc(h.Status) + '</span></div>';

        var max = 5;

        var head = '<tr><th>SKU</th><th>PACKING</th><th>SHIP QTY</th><th>REC QTY</th><th>Expiry date</th><th>Nitrogen</th><th>DIFF ( +/-)</th>';
        for (var i = 1; i <= max; i++) head += '<th>PAL-' + i + '</th>';
        head += '<th>TOTAL</th><th>Status</th><th>Notes</th></tr>';
        document.getElementById('detailHead').innerHTML = head;

        document.getElementById('detailBody').innerHTML = d.Items.map(function (x) {
            var r = '<tr class="row-' + String(x.CompareStatus || '').toLowerCase() + '">' +
                '<td><strong>' + App.esc(x.SKU) + '</strong></td>' +
                '<td class="packing">' + App.esc(x.ItemName) + '</td>' +
                '<td class="num">' + x.ExpectedQty + '</td>' +
                '<td class="num"><strong>' + x.TotalPhysicalQty + '</strong></td>' +
                '<td>' + App.esc(x.ExpiryDate || '') + '</td>' +
                '<td>' + App.esc(x.Nitrogen || '') + '</td>' +
                '<td class="num diff">' + (x.DifferenceQty > 0 ? '+' : '') + x.DifferenceQty + '</td>';

            var palletTotal = 0, hasPallet = false;
            for (var i = 1; i <= max; i++) {
                var p = (x.Pallets || []).find(function (z) { return z.PalletNo === i; });
                if (p) { palletTotal += Number(p.Quantity || 0); hasPallet = true; }
                r += '<td class="num">' + (p ? p.Quantity : '') + '</td>';
            }
            r += '<td class="num"><strong>' + (hasPallet ? palletTotal : '') + '</strong></td>' +
                 '<td><span class="pill ' + String(x.CompareStatus || '').toLowerCase() + '">' + App.esc(x.CompareStatus) + '</span></td>' +
                 '<td>' + App.esc(x.Notes) + '</td></tr>';
            return r;
        }).join('');

        var mis = d.Items.filter(function (x) { return x.CompareStatus !== 'Matched'; }).length;
        document.getElementById('detailMetrics').innerHTML = '<span><b>' + d.Items.length + '</b> items</span><span><b>' + mis + '</b> mismatches</span>';
        document.getElementById('documents').innerHTML = d.Documents.map(function (x) {
            return '<div class="doc-row"><a href="Handlers/DocumentDownload.ashx?id=' + x.DocumentId + '">' + App.esc(x.OriginalFileName) + '</a><span class="pill draft">' + App.esc(x.ExtractionStatus) + '</span></div>';
        }).join('') || '<div class="muted">No uploaded documents.</div>';
        document.getElementById('verificationInfo').innerHTML = '<p><b>Verified by:</b> ' + App.esc(h.VerifiedBy || 'Not verified') + '</p><p><b>Verified date:</b> ' + App.fmtDate(h.VerifiedDate) + '</p><p><b>Existing notes:</b> ' + App.esc(h.VerificationNotes || '-') + '</p>';
        document.getElementById('verifyBtn').disabled = h.Status !== 'Ready for Verification';
        document.getElementById('completeBtn').disabled = h.Status !== 'Verified';
        document.getElementById('auditBody').innerHTML = d.Audit.map(function (a) {
            return '<tr><td>' + App.fmtDate(a.ChangedDate) + '</td><td>' + App.esc(a.ActionType) + '</td><td>' + App.esc(a.EntityType) + '</td><td>' + App.esc(a.FieldName) + '</td><td>' + App.esc(a.OldValue) + '</td><td>' + App.esc(a.NewValue) + '</td><td>' + App.esc(a.ChangedBy) + '</td></tr>';
        }).join('') || '<tr><td colspan="7" class="empty">No audit entries.</td></tr>';
    }

    return {
        load: load,
        verify: function () {
            App.post('UnloadCompareDetails.aspx', 'Verify', { receivingId: id, notes: document.getElementById('verifyNotes').value })
                .then(function (r) { if (!r.IsSuccess) throw new Error(r.Message); App.toast(r.Message); load(); })
                .catch(function (e) { App.toast(e.message, true); });
        },
        complete: function () {
            App.post('UnloadCompareDetails.aspx', 'Complete', { receivingId: id, notes: document.getElementById('verifyNotes').value })
                .then(function (r) { if (!r.IsSuccess) throw new Error(r.Message); App.toast(r.Message); load(); })
                .catch(function (e) { App.toast(e.message, true); });
        },
        exportExcel: function () { location.href = 'Handlers/ExcelExport.ashx?id=' + id; },
        printReport: function () { window.open('UnloadComparePrint.aspx?id=' + id, '_blank'); }
    };
})();

document.addEventListener('DOMContentLoaded', UCD.load);
