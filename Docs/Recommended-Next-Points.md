# Babco Unload Compare - Recommended Next Production Points

These are the main operational points still worth adding after v1.2.0. They are recommendations, not hidden assumptions in the current workflow.

1. **Dock / Door Number** - identify where the container was unloaded.
2. **Unload Start Time / End Time** - measure actual unloading duration and labor productivity.
3. **Container Seal Number + Seal Photo** - record receiving integrity before unloading.
4. **Mismatch Reason Code** - require a reason for Short/Over rows before verification (damage, supplier short, count error, sample, etc.).
5. **Damage / Reject Quantity** - keep damaged cases separate from physically received usable cases.
6. **Unloader vs. Verifier Separation** - prevent the same person from entering and verifying a completed receiving record unless an admin override is audited.
7. **Autosave / Unsaved Changes Warning** - protect tablet/warehouse entry from browser refresh, sleep, or accidental navigation.
8. **Completed Record Lock** - completed data should be read-only; reopening should require an admin reason and create an audit entry.
9. **Azure Blob Document Storage** - store receiving sheets/images outside local App_Data for scale-out and safer retention.
10. **DB Health / Diagnostics** - show Application DB and Babco Support DB connectivity separately without exposing passwords.
11. **Role-Based Access** - Warehouse, Verifier, Manager, Admin.
12. **Operational Monitoring** - log failed imports, failed uploads, SQL timeouts, deployment health, and verification exceptions.
13. **Container / PO Duplicate Warning** - warn if the same container/PO is already active or completed.
14. **Mobile Barcode / SKU Scan** - optional scanner-assisted row focus for faster warehouse counting.
15. **Dashboard KPIs** - unloads today, matched %, shortage/overage count, average unload duration, pending verification.
