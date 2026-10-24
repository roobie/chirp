import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseDoc } from './frontmatter.mjs';

const fm = (text) => parseDoc(`---\n${text}\n---\n`).fm;

test('returns the whole text as body when there is no front matter', () => {
  assert.deepEqual(parseDoc('Hello'), { fm: null, body: 'Hello' });
});

test('parses scalars and returns a plain object', () => {
  const doc = parseDoc('---\ntitle: Hello\n---\nBody');
  assert.deepEqual(doc, { fm: { title: 'Hello' }, body: 'Body' });
  assert.equal(Object.getPrototypeOf(doc.fm), Object.prototype);
});

test('parses block lists', () => {
  assert.deepEqual(fm('tags:\n  - one\n  - two'), { tags: ['one', 'two'] });
});

test('parses inline lists with quoted commas', () => {
  assert.deepEqual(fm('tags: ["one, two", three]'), { tags: ['one, two', 'three'] });
});

test('block-list items with brackets are plain strings', () => {
  assert.deepEqual(fm('read_if:\n  - running the bench [threads]\n  - [link](url) works\n  - [a, b]'), {
    read_if: ['running the bench [threads]', '[link](url) works', '[a, b]'],
  });
});

test('a scalar is an inline list only when it starts with [ and ends with ]', () => {
  assert.deepEqual(fm('title: see [1]'), { title: 'see [1]' });
  assert.deepEqual(fm('title: [1] see'), { title: '[1] see' });
  assert.deepEqual(fm('title: [a, b]'), { title: ['a', 'b'] });
  assert.deepEqual(fm('title: []'), { title: [] });
});

test('an apostrophe inside an inline-list item is not a quote', () => {
  assert.deepEqual(fm("read_if: [don't panic, b]"), { read_if: ["don't panic", 'b'] });
  assert.deepEqual(fm(`read_if: ['it, really', "x"]`), { read_if: ['it, really', 'x'] });
});

test('rejects an unterminated quote at the start of an inline-list item', () => {
  assert.throws(() => fm('read_if: ["a, b]'), /unterminated quote/);
});

test('drops empty inline-list items', () => {
  assert.deepEqual(fm('read_if: [a, b,]'), { read_if: ['a', 'b'] });
});

test('rejects list items without a list key', () => {
  assert.throws(() => parseDoc('---\n  - orphan\n---\n'), /list item without a list key/);
});

test('rejects duplicate keys and __proto__', () => {
  assert.throws(() => parseDoc('---\ntitle: A\ntitle: B\n---\n'), /duplicate front matter key/);
  assert.throws(() => parseDoc('---\n__proto__: x\n---\n'), /reserved front matter key/);
});

// Parity: main's pre-extraction parser (verbatim from dev-proc.mjs before the parser moved here)
// must give identical output on every document in the repo's .work/ trees and on edge cases.
const unquote = (s) => s.replace(/^(['"])(.*)\1$/, '$2');

function oldParseDoc(text) {
  const m = text.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?([\s\S]*)$/);
  if (!m) return { fm: null, body: text };
  const out = {};
  let key = null;
  for (const line of m[1].split(/\r?\n/)) {
    if (!line.trim() || /^\s*#/.test(line)) continue;
    const item = line.match(/^\s+-\s+(.*)$/);
    if (item && key && Array.isArray(out[key])) { out[key].push(unquote(item[1].trim())); continue; }
    const kv = line.match(/^([A-Za-z_][\w-]*):(?:\s+(.*))?$/);
    if (!kv) throw new Error(`unparseable front matter line: "${line}"`);
    key = kv[1];
    const v = (kv[2] ?? '').trim();
    if (v === '') out[key] = [];
    else if (/^\[.*\]$/.test(v)) out[key] = v.slice(1, -1).split(',').map((s) => unquote(s.trim())).filter(Boolean);
    else out[key] = unquote(v);
  }
  return { fm: out, body: m[2] };
}

const markdownUnder = (dir) => fs.readdirSync(dir, { withFileTypes: true }).flatMap((e) => {
  const p = path.join(dir, e.name);
  if (e.isDirectory()) return markdownUnder(p);
  return p.endsWith('.md') ? [p] : [];
});

test('parity with the previous parser on every .work document', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../../.work');
  const files = fs.existsSync(root) ? markdownUnder(root) : [];
  for (const file of files) {
    const text = fs.readFileSync(file, 'utf8');
    assert.deepEqual(parseDoc(text), oldParseDoc(text), file);
  }
});

test('parity with the previous parser on edge cases', () => {
  const cases = [
    '---\r\ntitle: A\r\nread_if:\r\n  - x\r\n---\r\nbody',
    '---\ntitle: "a: b"\nstatus: \'x\'\n---\n',
    '---\nread_if: []\n---\n',
    '---\nread_if: [a, b,]\n---\n',
    '---\nread_if: ["x", \'y\', z]\nrefs:\n  - a#b\n  - c/d\n---\nbody\n', // (quoted commas are the one intended difference)
    '---\na: [x]\n  - y\n---\n',
    '---\nowner:\n  - TODO\n---\n',
    '---\nread_if:\n---\n',
    '---\n# comment\n\na: 1\n---',
    '---\na:\n\t- x\n---\n',
  ];
  for (const text of cases) assert.deepEqual(parseDoc(text), oldParseDoc(text), text);
});
