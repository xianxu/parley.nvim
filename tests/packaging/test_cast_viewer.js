#!/usr/bin/env node
'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');
const html = fs.readFileSync(path.join(__dirname, '../../demo/viewer.html'), 'utf8');
const script = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)][0][1];
const KEY = 'cast-viewer-drafts:v1';
function storage() {
  const values = new Map();
  return { values, readError: false, writeError: false,
    get length() { return values.size; },
    key(index) { return [...values.keys()][index] ?? null; },
    removeItem(key) { values.delete(key); },
    getItem(key) { if (this.readError) throw Error('read denied'); return values.get(key) ?? null; },
    setItem(key, value) { if (this.writeError) throw Error('quota'); values.set(key, value); },
  };
}
function viewer(store = storage(), cast = 'demo.cast') {
  const elements = {};
  for (const [, id] of html.matchAll(/id="([^"]+)"/g)) elements[id] = {
    value: '', textContent: '', checked: false, listeners: {},
    addEventListener(name, fn) { this.listeners[name] = fn; },
    dispatchEvent(event) { return this.listeners[event.type]?.(event); },
  };
  const loaded = [], downloads = [];
  const document = { getElementById: id => elements[id], addEventListener() {},
    createElement: () => ({ click() {} }) };
  const context = vm.createContext({ document, location: { search: '?cast=' + encodeURIComponent(cast) },
    localStorage: store, URLSearchParams, URL: { createObjectURL(blob) { downloads.push(blob); return 'blob:test'; }, revokeObjectURL() {} },
    Blob, Event, setInterval() {}, AsciinemaPlayer: { create(source) {
      loaded.push(source); return { dispose() {}, addEventListener() {}, getCurrentTime() { return 0; } };
    } } });
  vm.runInContext(script, context);
  return { elements, loaded, downloads,
    select(file) { return elements.file.listeners.change({ target: { files: [file] } }); },
    edit(value) { elements.notes.value = value; elements.notes.listeners.input(); },
  };
}
function deferredFile(name) {
  let resolve, reject;
  const promise = new Promise((yes, no) => { resolve = yes; reject = no; });
  return { name, text: () => promise, resolve, reject };
}
for (const order of ['older-first', 'newer-first']) test('latest selected file wins: ' + order, async () => {
  const v = viewer(), a = deferredFile('a.cast'), b = deferredFile('b.cast');
  const pa = v.select(a), pb = v.select(b);
  if (order === 'older-first') { a.resolve('A'); await pa; b.resolve('B'); await pb; }
  else { b.resolve('B'); await pb; a.resolve('A'); await pa; }
  assert.equal(v.loaded.at(-1).data, 'B');
  assert.equal(v.elements.src.textContent, 'b.cast');
  assert.equal(v.loaded.some(source => source.data === 'A'), false);
});
test('current file error visible; superseded error ignored', async () => {
  const v = viewer(), a = deferredFile('a.cast'), b = deferredFile('b.cast');
  const pa = v.select(a), pb = v.select(b);
  b.resolve('B'); await pb; a.reject(Error('stale')); await pa;
  assert.equal(v.elements.src.textContent, 'b.cast');
  const c = deferredFile('c.cast'), pc = v.select(c); c.reject(Error('denied')); await pc;
  assert.match(v.elements['load-status'].textContent, /could not.*c.cast/i);
  assert.equal(v.loaded.at(-1).data, 'B');
});
test('drafts keep only 20 most recently saved casts in one storage entry', () => {
  const store = storage();
  for (let i = 0; i < 25; i++) viewer(store, 'cast-' + i).edit('note-' + i);
  assert.equal(store.values.size, 1);
  assert.equal(JSON.parse(store.values.get(KEY)).length, 20);
  assert.equal(viewer(store, 'cast-0').elements.notes.value, '');
  assert.equal(viewer(store, 'cast-5').elements.notes.value, 'note-5');
  viewer(store, 'cast-5').edit('updated');
  viewer(store, 'cast-25').edit('new');
  assert.equal(viewer(store, 'cast-6').elements.notes.value, '');
  assert.equal(viewer(store, 'cast-5').elements.notes.value, 'updated');
});
test('quota failure keeps complete in-memory text downloadable and marks unsaved', async () => {
  const store = storage(), v = viewer(store);
  v.edit('saved'); store.writeError = true;
  const note = 'new '.repeat(10000); v.edit(note);
  assert.equal(v.elements.notes.value, note);
  assert.match(v.elements['draft-status'].textContent, /unsaved/i);
  v.elements.download.listeners.click();
  assert.equal(await v.downloads[0].text(), note);
  assert.equal(viewer(store).elements.notes.value, 'saved');
  store.writeError = false; v.edit(note);
  assert.match(v.elements['draft-status'].textContent, /saved/i);
  assert.doesNotMatch(v.elements['draft-status'].textContent, /unsaved/i);
  assert.equal(viewer(store).elements.notes.value, note);
});
test('load/storage read failure is visible and cannot overwrite unread drafts', async () => {
  const store = storage(); viewer(store).edit('existing'); store.readError = true;
  const v = viewer(store);
  assert.match(v.elements['draft-status'].textContent, /unsaved/i);
  v.edit('in memory');
  v.elements.download.listeners.click();
  assert.equal(await v.downloads[0].text(), 'in memory');
  assert.match(v.elements['draft-status'].textContent, /unsaved/i);
  store.readError = false;
  assert.equal(viewer(store).elements.notes.value, 'existing');
});
test('malformed stored drafts remain intact and expose unsaved status', () => {
  const store = storage(); store.values.set(KEY, '{broken');
  const v = viewer(store); v.edit('new note');
  assert.match(v.elements['draft-status'].textContent, /unsaved/i);
  assert.equal(store.values.get(KEY), '{broken');
});

test('legacy drafts migrate once, retaining 20 and cleaning only after persistence', () => {
  const store = storage();
  for (let i = 0; i < 25; i++) store.values.set('cast-viewer-notes:cast-' + i, 'legacy-' + i);
  store.writeError = true;
  const failed = viewer(store, 'cast-24');
  assert.match(failed.elements['draft-status'].textContent, /unsaved/i);
  assert.equal(failed.elements.notes.value, 'legacy-24');
  assert.equal(store.values.size, 25);
  store.writeError = false;
  const migrated = viewer(store, 'cast-24');
  assert.equal(migrated.elements.notes.value, 'legacy-24');
  assert.equal(store.values.size, 1);
  assert.equal(JSON.parse(store.values.get(KEY)).length, 20);
  assert.equal(viewer(store, 'cast-5').elements.notes.value, 'legacy-5');
  assert.equal(viewer(store, 'cast-0').elements.notes.value, '');
});
