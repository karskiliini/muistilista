// Validate untrusted URL/localStorage data before it can replace the saved list.
function validStore(value, enforceImportLimits = true) {
  if (!value || typeof value !== 'object' || typeof value.listName !== 'string' || (enforceImportLimits && value.listName.length > 128) ||
      !Array.isArray(value.categories) || (enforceImportLimits && value.categories.length > 100)) return null;
  let count = 0;
  for (const category of value.categories) {
    if (!category || typeof category.name !== 'string' || (enforceImportLimits && category.name.length > 256) || !Array.isArray(category.items)) return null;
    count += category.items.length;
    if ((enforceImportLimits && count > 1000) || category.items.some(item => !item || typeof item.n !== 'string' || (enforceImportLimits && item.n.length > 256) || typeof item.p !== 'boolean')) return null;
  }
  // Reconstruct only the expected properties; keep no prototype/extra fields.
  return { listName: value.listName, categories: value.categories.map(c => ({ name: c.name, items: c.items.map(i => ({ n: i.n, p: i.p })) })) };
}
function importedStore(raw) {
  if (typeof raw !== 'string' || raw.length > 64 * 1024) return null;
  try {
    let parsed;
    try { parsed = JSON.parse(raw); } catch { parsed = JSON.parse(decodeURIComponent(raw)); }
    if (!parsed || !Array.isArray(parsed.items)) return null;
    return validStore({ listName: parsed.n, categories: parsed.items.map(c => ({ name: c.c, items: Array.isArray(c.i) ? c.i.map(n => ({ n, p: false })) : null })) });
  } catch { return null; }
}
if (typeof module !== 'undefined') module.exports = { validStore, importedStore };
