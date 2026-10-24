import { test } from 'node:test';
import assert from 'node:assert/strict';
import { findRecords, stem, tokenize } from './find.mjs';

const rec = (id, title, readIf = []) => ({ id, kind: 'decision', title, readIf });
const ids = (hits) => hits.map((h) => h.id);

// Filler records so that a word in one or two records is "rare" (a quarter of the corpus or less).
const filler = Array.from({ length: 12 }, (_, i) => rec(`D-FILL${String(i).padStart(2, '0')}`, `Filler ${i}`, ['unrelated work']));

const corpus = [
  rec('D-SHADER', 'Shaders are authored in Slang', ['adding or changing a shader', 'crates/view/src/dots.slang']),
  rec('L-WGSL', 'Slang output is machine-shaped', ['debugging a shader or reading generated WGSL']),
  rec('D-COLOUR', 'Colours are blended in gamma space', ['changing the colour palette', 'adding translucent overlays']),
  rec('D-RANDOM', 'Randomness comes from stateless streams', ['adding randomness to the sim']),
  rec('D-RNG', 'Deterministic simulation', ['touching simulation tick, RNG or float ordering']),
  rec('L-MORALE', 'Fight outcomes are noisy without morale', ['writing an outcome test']),
  ...filler,
];

test('stems inflections and spelling variants alike', () => {
  assert.equal(stem('changing'), stem('change'));
  assert.equal(stem('changes'), stem('changed'));
  assert.equal(stem('colour'), stem('color'));
  assert.equal(stem('optimising'), stem('optimize'));
  assert.equal(stem('optimizes'), stem('optimise'));
  assert.equal(stem('running'), stem('run'));
  assert.equal(stem('class'), 'clas');
});

test('tokenize drops stopwords and duplicates', () => {
  assert.deepEqual(tokenize('Touching the RNG, the RNG'), [stem('touching'), 'random']);
});

test('ranks by distinct query tokens hit, read_if above title, ties by id', () => {
  const hits = findRecords(corpus, 'debugging a shader');
  assert.deepEqual(ids(hits).slice(0, 3), ['L-WGSL', 'D-SHADER']);
  assert.ok(hits[0].score > hits[1].score);
  assert.deepEqual(hits[0].matched, ['debug', 'shader']);
});

test('multi-word queries prefer records that hit more tokens', () => {
  const hits = findRecords(corpus, 'adding randomness to the sim');
  assert.equal(hits[0].id, 'D-RANDOM');
});

test('a title-only hit still matches, below a cue hit', () => {
  const hits = findRecords(corpus, 'morale outcome');
  assert.equal(hits[0].id, 'L-MORALE');
  assert.deepEqual(hits[0].cues, ['writing an outcome test']);
});

test('rng and randomness are the same concept', () => {
  assert.deepEqual(ids(findRecords(corpus, 'touching the RNG')).sort(), ['D-RANDOM', 'D-RNG']);
});

test('colour and color, optimise and optimize match', () => {
  assert.equal(findRecords(corpus, 'color').at(0).id, 'D-COLOUR');
  const records = [...filler, rec('D-OPT', 'Tick cost', ['optimising the tick'])];
  assert.deepEqual(ids(findRecords(records, 'optimizing')), ['D-OPT']);
});

test('a token that hits most records is ignored when a rarer one is present', () => {
  const records = [...filler.map((r) => ({ ...r, readIf: ['changing things'] })), rec('D-ONE', 'Odd', ['changing the quux'])];
  assert.deepEqual(ids(findRecords(records, 'changing quux')), ['D-ONE']);
  assert.equal(findRecords(records, 'changing').length, records.length);
});

test('ref-style cues are neither matched nor reported', () => {
  const hits = findRecords(corpus, 'slang dots');
  assert.deepEqual(ids(hits), ['D-SHADER', 'L-WGSL']);
  assert.ok(hits.every((h) => !h.cues.some((c) => c.includes('/'))));
});

test('no match, empty query', () => {
  assert.deepEqual(findRecords(corpus, 'xyzzy'), []);
  assert.deepEqual(findRecords(corpus, 'the of'), []);
});
