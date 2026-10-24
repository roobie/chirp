import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const CLI = path.join(path.dirname(fileURLToPath(import.meta.url)), 'dev-proc.mjs');
const run = (cwd, ...args) => spawnSync('node', [CLI, ...args], { cwd, encoding: 'utf8' });

// A throwaway git repo with an initialised .work/ and two durable records.
function scratchRepo() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'dev-proc-test-'));
  execFileSync('git', ['init', '-q'], { cwd: dir });
  assert.equal(run(dir, 'init').status, 0);
  const rec = (kind, args) => {
    const r = run(dir, 'record', kind, ...args);
    assert.equal(r.status, 0, r.stderr);
  };
  rec('decision', ['Shaders come from Slang', '--read-if', 'changing a shader', '--read-if', 'adding a render pipeline']);
  rec('learning', ['Bench threads are noisy', '--read-if', 'running the bench [threads]']);
  return dir;
}

test('--help and -h print usage', () => {
  for (const flag of ['--help', '-h']) {
    const r = run(os.tmpdir(), flag);
    assert.equal(r.status, 0);
    assert.match(r.stdout, /find <words…>/);
  }
});

test('find --help and find -h print the find usage', () => {
  const dir = scratchRepo();
  try {
    for (const flag of ['--help', '-h']) {
      const r = run(dir, 'find', flag);
      assert.equal(r.status, 0);
      assert.match(r.stdout, /^usage: find <words…>/);
    }
  } finally {
    fs.rmSync(dir, { recursive: true });
  }
});

test('find lists matching records with their cues, as text and JSON', () => {
  const dir = scratchRepo();
  try {
    const text = run(dir, 'find', 'changing', 'a', 'shader');
    assert.equal(text.status, 0);
    assert.match(text.stdout, /^D-\w{16} {2}Shaders come from Slang\n {4}read if: changing a shader\n$/);

    const json = JSON.parse(run(dir, 'find', 'changing a shader', '--json').stdout);
    assert.equal(json.length, 1);
    assert.deepEqual(json[0].cues, ['changing a shader']);
    assert.equal(json[0].kind, 'decision');

    assert.match(run(dir, 'find', 'xyzzy').stdout, /no decisions or learnings match "xyzzy"/);
    assert.equal(run(dir, 'find').status, 2);
  } finally {
    fs.rmSync(dir, { recursive: true });
  }
});

test('a read_if with brackets is recorded, then passes check and is found', () => {
  const dir = scratchRepo();
  try {
    const check = run(dir, 'check');
    assert.equal(check.status, 0, check.stdout + check.stderr);
    assert.match(run(dir, 'find', 'bench').stdout, /read if: running the bench \[threads\]/);
  } finally {
    fs.rmSync(dir, { recursive: true });
  }
});

test('status prints the find hint on the counts line, not in JSON', () => {
  const dir = scratchRepo();
  try {
    assert.match(run(dir, 'status').stdout, /learnings: 1 \(find "<topic>" lists the ones to read\)\n$/);
    assert.doesNotMatch(run(dir, 'status', '--json').stdout, /find "<topic>"/);
  } finally {
    fs.rmSync(dir, { recursive: true });
  }
});
