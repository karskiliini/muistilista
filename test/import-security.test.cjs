const { test } = require('node:test');
const assert = require('node:assert/strict');
const { validStore, importedStore } = require('../web/store-validation.js');

test('untrusted imported fields cannot reach HTML string rendering as objects', () => {
  for (const item of [{ n: { replace: 'not callable' }, items: [] }, { n: 'ok', items: [{ c: 'a', i: [{}] }] }, { n: 'ok', items: [{ c: 'a', i: null }] }]) {
    assert.equal(importedStore(JSON.stringify(item)), null);
  }
  assert.equal(importedStore(JSON.stringify({ n: 'ok', items: Array(101).fill({ c: 'a', i: [] }) })), null);
  assert.equal(importedStore('x'.repeat(65537)), null);
});
test('valid unicode lists and percent signs survive normal and legacy encoded links', () => {
  const value = { n: 'Mökki 100%', items: [{ c: 'Ruoka', i: ['Maito <tag>', 'Leipä'] }] };
  for (const raw of [JSON.stringify(value), encodeURIComponent(JSON.stringify(value))]) {
    const result = importedStore(raw);
    assert.equal(result.listName, value.n);
    assert.equal(result.categories[0].items[0].n, 'Maito <tag>');
  }
});
test('URL import rejection leaves the current list and storage untouched', () => {
  const fs = require('node:fs'); const vm = require('node:vm');
  const html = fs.readFileSync(require('node:path').join(__dirname, '../web/index.html'), 'utf8');
  const inline = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].at(-1)[1].replace(/    \/\/ ── Init ──[\s\S]*$/, '');
  let writes = 0;
  const context = vm.createContext({ URLSearchParams, localStorage: { getItem: () => null, setItem: () => { writes++; } }, window: { location: { search: '?list=' + encodeURIComponent('{"n":"attack","items":[{"c":"x","i":[{}]}]}') } } });
  vm.runInContext(fs.readFileSync(require('node:path').join(__dirname, '../web/store-validation.js'), 'utf8'), context);
  vm.runInContext(inline, context);
  const before = vm.runInContext('JSON.stringify(store)', context);
  vm.runInContext('checkURLImport()', context);
  assert.equal(vm.runInContext('JSON.stringify(store)', context), before);
  assert.equal(writes, 0);
});
