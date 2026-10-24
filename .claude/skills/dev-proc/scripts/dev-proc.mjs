#!/usr/bin/env node
// dev-proc — the CLI half of the dev-proc skill.
// Mode is never stored separately: it is derived from the .work/ tree on disk.
// No dependencies; front matter is a restricted YAML subset (scalars, [inline], and "- item" lists).
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { parseDoc } from './frontmatter.mjs';
import { findRecords } from './find.mjs';

const TYPES = ['project', 'milestone', 'wave', 'slice', 'task']; // high → low
const PHASES = ['initialize', 'execute', 'finalize'];
const RECORDS = {
  decision: { dir: 'decisions', prefix: 'D', durable: true },
  learning: { dir: 'learnings', prefix: 'L', durable: true },
  backlog: { dir: 'backlog', prefix: 'B', durable: false },
};
const NAME_RE = /^[a-z0-9][a-z0-9-]*$/;
const RECORD_ID_RE = /^([DLB])-([A-Z2-7]{16})$/;
const RECORD_ID_PREFIX_RE = /^[DLB]-[A-Z2-7]{16}\s+/; // record headings read "# D-… Title"
// Unit ids carry no type, so a rescoped unit keeps its id (and its Work: trailer history).
const UNIT_ID_RE = /^U-[A-Z2-7]{16}$/;
const UNIT_DIR_RE = /^(U-[A-Z2-7]{16})-([a-z0-9][a-z0-9-]*)$/;
const BASE32 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'; // RFC 4648
const SCRIPT = fileURLToPath(import.meta.url);
const TEMPLATES = path.resolve(path.dirname(SCRIPT), '..', 'templates');
const STRICT = process.env.DEV_PROC_STRICT === '1';
const HOOK_MARKER = '# installed by dev-proc';

class UsageError extends Error {}
const die = (msg) => { throw new UsageError(msg); };
const print = (s = '') => process.stdout.write(s + '\n');
const today = () => new Date().toISOString().slice(0, 10);
const rank = (type) => TYPES.indexOf(type);
const isTodo = (s) => /^TODO\b/.test(String(s));
const list = (v) => (Array.isArray(v) ? v : v ? [v] : []).filter((x) => x && !isTodo(x));

// ---------- git / paths

function git(args, cwd) {
  return execFileSync('git', args, { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], maxBuffer: 64 << 20 });
}

function tryGit(args, cwd) {
  try { return git(args, cwd); } catch { return ''; }
}

function repoTop(cwd) {
  try { return git(['rev-parse', '--show-toplevel'], cwd).trim(); }
  catch { die('not inside a git repository'); }
}

const posix = (p) => p.split(path.sep).join('/');
const rel = (top, p) => posix(path.relative(top, p));

// ---------- front matter

function dumpDoc(fm, body) {
  const out = [];
  for (const [k, v] of Object.entries(fm)) {
    if (v === undefined || v === null) continue;
    if (Array.isArray(v)) { out.push(`${k}:`); for (const i of v) out.push(`  - ${i}`); }
    else out.push(`${k}: ${v}`);
  }
  return `---\n${out.join('\n')}\n---\n${body}`;
}

function template(name, vars) {
  const text = fs.readFileSync(path.join(TEMPLATES, name), 'utf8');
  return text.replace(/\{\{(\w+)\}\}/g, (_, k) => vars[k] ?? '');
}

const titleOf = (body) => body.match(/^#\s+(.*)$/m)?.[1].trim() ?? '';

function section(body, heading) {
  const m = body.match(new RegExp(`^## ${heading}\\s*$([\\s\\S]*?)(?=^## |(?![\\s\\S]))`, 'm'));
  return m ? m[1] : '';
}

// Log is the last section of STATE.md by convention, so appending to the file appends to it.
function appendLog(file, line) {
  const text = fs.readFileSync(file, 'utf8');
  fs.writeFileSync(file, text.replace(/\s*$/, '\n') + `- ${today()} ${line}\n`);
}

// ---------- model

function loadRoot(dir) {
  const units = [];
  for (const type of TYPES) {
    const tdir = path.join(dir, type);
    if (!fs.existsSync(tdir)) continue;
    for (const entry of fs.readdirSync(tdir).sort()) {
      const udir = path.join(tdir, entry);
      if (!fs.statSync(udir).isDirectory()) continue;
      const statePath = path.join(udir, 'STATE.md');
      const m = entry.match(UNIT_DIR_RE);
      const name = m?.[2] ?? entry;
      const u = { id: m?.[1] ?? entry, label: `${type}/${name}`, type, name, dir: udir, statePath, fm: null, body: '', problems: [] };
      if (!m) u.problems.push(`directory "${entry}" must be U-<16 base32 chars>-<kebab-name>`);
      if (!fs.existsSync(statePath)) u.problems.push('missing STATE.md');
      else {
        try {
          const d = parseDoc(fs.readFileSync(statePath, 'utf8'));
          u.fm = d.fm; u.body = d.body;
          if (!u.fm) u.problems.push('STATE.md has no front matter');
        } catch (e) { u.problems.push(e.message); }
      }
      units.push(u);
    }
  }
  const records = [];
  for (const [kind, spec] of Object.entries(RECORDS)) {
    const rdir = path.join(dir, spec.dir);
    if (!fs.existsSync(rdir)) continue;
    for (const f of fs.readdirSync(rdir).sort()) {
      if (!f.endsWith('.md')) continue;
      const file = path.join(rdir, f);
      const id = f.match(/^([DLB]-[A-Z2-7]{16})(?:-|\.md$)/)?.[1] ?? null;
      const r = { kind, spec, file, id, fm: null, body: '', problems: [] };
      if (!id || id[0] !== spec.prefix) r.problems.push(`filename must start with ${spec.prefix}-<16 base32 chars>-`);
      try {
        const d = parseDoc(fs.readFileSync(file, 'utf8'));
        r.fm = d.fm; r.body = d.body;
        if (!r.fm) r.problems.push('no front matter');
      } catch (e) { r.problems.push(e.message); }
      records.push(r);
    }
  }
  return { dir, base: path.dirname(dir), units, records };
}

const parentOf = (u) => (typeof u.fm?.parent === 'string' ? u.fm.parent : null);
const childrenOf = (root, id) => root.units.filter((u) => parentOf(u) === id);

// Accepts a unit id (U-…) or, as a convenience, its type/name label.
function findUnit(root, ref) {
  return root.units.find((u) => u.id === ref || u.label === ref) ?? die(`no active unit "${ref}" in ${root.dir}`);
}

const show = (u) => `${u.id} ${u.label}`;

function findRecord(root, id) {
  return root.records.find((r) => r.id === id) ?? die(`no record "${id}" in ${root.dir}`);
}

// Every .work/ root in the repo, honouring .gitignore; includes untracked ones.
function allRoots(top) {
  const roots = new Set();
  for (const f of git(['ls-files', '-z', '--cached', '--others', '--exclude-standard'], top).split('\0')) {
    const segs = f.split('/');
    const i = segs.indexOf('.work');
    if (i >= 0) roots.add(path.join(top, ...segs.slice(0, i + 1)));
  }
  return [...roots].filter((d) => fs.existsSync(d)).sort();
}

function nearestRoot(cwd, top) {
  for (let d = cwd; ; d = path.dirname(d)) {
    if (fs.existsSync(path.join(d, '.work'))) return path.join(d, '.work');
    if (d === top || d === path.dirname(d)) return null;
  }
}

// 80 random bits, base32 (16 chars, no padding): unique across branches without coordination.
// Used for both units (U-) and records (D-, L-, B-).
function newIdent(prefix) {
  const bytes = randomBytes(10);
  let bits = 0;
  let acc = 0;
  let out = '';
  for (const b of bytes) {
    acc = (acc << 8) | b;
    bits += 8;
    while (bits >= 5) {
      out += BASE32[(acc >>> (bits - 5)) & 31];
      bits -= 5;
    }
  }
  return `${prefix}-${out}`;
}

const slugify = (s) => s.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 50).replace(/-+$/, '');

// ---------- gates

function gateProblems(root, u, to) {
  const fm = u.fm ?? {};
  const p = [];
  if (to === 'execute' || to === 'finalize') {
    if (!list(fm.success_criteria).length) p.push('success_criteria is empty');
    if (!list(fm.owner).length) p.push('owner is empty');
  }
  if (to === 'closed') {
    if (fm.phase !== 'finalize') p.push(`phase is "${fm.phase}", must be "finalize"`);
    const kids = childrenOf(root, u.id);
    if (kids.length) p.push(`open children: ${kids.map(show).join(', ')}`);
    const open = (section(u.body, 'Harvest').replace(/<!--[\s\S]*?-->/g, '').match(/^\s*- \[ \]/gm) ?? []).length;
    if (open) p.push(`${open} unchecked item(s) in ## Harvest — promote or drop them first`);
  }
  return p;
}

// ---------- commands

function cmdInit(ctx, args) {
  const dir = path.resolve(ctx.cwd, args._[0] ?? '.', '.work');
  if (fs.existsSync(dir)) return print(`exists: ${dir}`);
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, '.gitkeep'), '');
  print(`created ${rel(ctx.top, dir)}/`);
}

function unitLine(u) {
  const fm = u.fm ?? {};
  const owner = list(fm.owner).join(', ') || '—';
  const warn = u.problems.length ? `  ⚠ ${u.problems.join('; ')}` : '';
  return `${show(u)}  [${fm.phase ?? '?'}]  owner: ${owner}${warn}`;
}

function cmdStatus(ctx, args) {
  const root = ctx.root();
  const [id] = args._;
  if (id) return statusOne(root, findUnit(root, id), args);
  if (args.json) {
    return print(JSON.stringify({
      root: rel(ctx.top, root.dir),
      units: root.units.map((u) => ({ id: u.id, label: u.label, phase: u.fm?.phase ?? null, parent: parentOf(u), owner: list(u.fm?.owner), problems: u.problems })),
      records: root.records.map((r) => ({ id: r.id, kind: r.kind, title: titleOf(r.body), read_if: list(r.fm?.read_if) })),
    }, null, 2));
  }
  print(`root: ${rel(ctx.top, root.dir) || '.work'}`);
  if (!root.units.length) print('mode: idle — no active units (curate the backlog, or `new`)');
  const ids = new Set(root.units.map((u) => u.id));
  const walk = (u, depth) => {
    print(`${'  '.repeat(depth)}${unitLine(u)}`);
    for (const c of childrenOf(root, u.id)) walk(c, depth + 1);
  };
  for (const u of root.units.filter((u) => !parentOf(u) || !ids.has(parentOf(u)))) walk(u, 0);
  const count = (k) => root.records.filter((r) => r.kind === k).length;
  print(`backlog: ${count('backlog')}  decisions: ${count('decision')}  learnings: ${count('learning')} (find "<topic>" lists the ones to read)`);
}

function statusOne(root, u, args) {
  const fm = u.fm ?? {};
  const next = { initialize: 'execute', execute: 'finalize', finalize: 'closed' }[fm.phase];
  const info = {
    id: u.id,
    label: u.label,
    mode: fm.phase ?? null,
    parent: parentOf(u),
    owner: list(fm.owner),
    success_criteria: list(fm.success_criteria),
    files: ['DESIGN.md', 'PLAN.md', 'STATE.md'].filter((f) => fs.existsSync(path.join(u.dir, f))),
    children: childrenOf(root, u.id).map((c) => `${show(c)} [${c.fm?.phase ?? '?'}]`),
    next,
    gate: next ? gateProblems(root, u, next) : [],
    problems: u.problems,
  };
  if (args.json) return print(JSON.stringify(info, null, 2));
  print(`${show(u)}\nmode: ${info.mode}`);
  if (info.parent) print(`parent: ${root.units.find((p) => p.id === info.parent)?.label ?? '?'} ${info.parent}`);
  print(`owner: ${info.owner.join(', ') || '—'}`);
  print(`files: ${info.files.join(', ')}`);
  print('success criteria:');
  for (const c of info.success_criteria) print(`  - ${c}`);
  if (info.children.length) print(`children:\n${info.children.map((c) => `  - ${c}`).join('\n')}`);
  if (next) print(`gate → ${next}: ${info.gate.length ? '\n  ✗ ' + info.gate.join('\n  ✗ ') : 'open'}`);
  if (info.problems.length) print(`problems:\n  ⚠ ${info.problems.join('\n  ⚠ ')}`);
}

// Resolves a parent reference to its id, checking it sits at a higher level.
function checkParent(root, type, parent) {
  if (!parent) return undefined;
  const p = findUnit(root, parent);
  if (rank(p.type) >= rank(type)) die(`parent ${p.label} must be a higher level than ${type}`);
  return p.id;
}

function cmdNew(ctx, args) {
  const [type, name] = args._;
  if (!TYPES.includes(type)) die(`type must be one of: ${TYPES.join(', ')}`);
  if (!NAME_RE.test(name ?? '')) die('name must be kebab-case: [a-z0-9-]');
  const root = ctx.root();
  const label = `${type}/${name}`;
  if (root.units.some((u) => u.label === label)) die(`${label} already exists`);
  const parent = checkParent(root, type, args.parent);
  const id = newIdent('U');

  let origin = '';
  if (args.from) {
    const b = findRecord(root, args.from);
    if (b.kind !== 'backlog') die(`${args.from} is not a backlog item`);
    // Demote the item's headings so they nest under Origin instead of becoming STATE sections.
    const detail = b.body.replace(/^#\s+.*$/m, '').trim().replace(/^(#{2,}) /gm, '#$1 ');
    origin = `\n### Origin\nPromoted from backlog: ${titleOf(b.body)}\n\n${detail}\n`;
    fs.rmSync(b.file);
  }

  const dir = path.join(root.dir, type, `${id}-${name}`);
  fs.mkdirSync(dir, { recursive: true });
  const fm = {
    phase: 'initialize',
    parent,
    owner: args.owner ? args.owner.split(',').map((s) => s.trim()) : ['TODO: person and/or agent'],
    created: today(),
    success_criteria: ['TODO: observable outcome that proves this unit is done'],
  };
  const vars = { id, label, date: today() };
  fs.writeFileSync(path.join(dir, 'STATE.md'), dumpDoc(fm, template('STATE.md', vars).replace('<!-- origin -->', origin.trim() ? origin : '')));
  const created = ['STATE.md'];
  for (const f of (args.with ?? '').split(',').filter(Boolean)) {
    const file = { design: 'DESIGN.md', plan: 'PLAN.md' }[f.trim()] ?? die(`--with takes design,plan`);
    fs.writeFileSync(path.join(dir, file), template(file, vars));
    created.push(file);
  }
  print(`created ${id} ${label}: ${rel(ctx.top, dir)}/ {${created.join(', ')}}  mode: initialize`);
  if (args.from) print(`consumed backlog ${args.from}`);
}

function cmdPhase(ctx, args) {
  const [id, to] = args._;
  if (!PHASES.includes(to)) die(`phase must be one of: ${PHASES.join(', ')} (use \`close\` to end a unit)`);
  const root = ctx.root();
  const u = findUnit(root, id);
  const from = u.fm?.phase;
  if (from === to) return print(`${show(u)} already in ${to}`);
  const forward = PHASES.indexOf(to) > PHASES.indexOf(from);
  const problems = forward ? gateProblems(root, u, to) : [];
  if (problems.length && !args.force) die(`gate → ${to} closed:\n  ✗ ${problems.join('\n  ✗ ')}\n(--force to override, and say why in the Log)`);
  fs.writeFileSync(u.statePath, dumpDoc({ ...u.fm, phase: to }, u.body));
  appendLog(u.statePath, `phase ${from} → ${to}${args.force && problems.length ? ' (forced)' : ''}`);
  print(`${show(u)}: ${from} → ${to}`);
}

function cmdRescope(ctx, args) {
  const root = ctx.root();
  const u = findUnit(root, args._[0]);
  const type = args.type ?? u.type;
  const name = args.name ?? u.name;
  if (!TYPES.includes(type)) die(`type must be one of: ${TYPES.join(', ')}`);
  if (!NAME_RE.test(name)) die('name must be kebab-case');
  const parent = args.parent === 'none' ? undefined : checkParent(root, type, args.parent ?? parentOf(u) ?? undefined);
  const kids = childrenOf(root, u.id);
  for (const k of kids) if (rank(k.type) <= rank(type)) die(`child ${k.label} would no longer be below a ${type}; rescope it first`);
  const label = `${type}/${name}`;
  if (label !== u.label && root.units.some((x) => x.label === label)) die(`${label} already exists`);

  // The id stays put, so children's parent refs and past Work: trailers remain valid.
  const newDir = path.join(root.dir, type, `${u.id}-${name}`);
  if (newDir !== u.dir) {
    fs.mkdirSync(path.dirname(newDir), { recursive: true });
    fs.renameSync(u.dir, newDir);
  }
  const statePath = path.join(newDir, 'STATE.md');
  fs.writeFileSync(statePath, dumpDoc({ ...u.fm, parent }, u.body.replace(/^# .*$/m, `# ${label}`)));
  appendLog(statePath, `rescoped ${u.label} → ${label}${parent !== parentOf(u) ? ` (parent ${parentOf(u) ?? 'none'} → ${parent ?? 'none'})` : ''}`);
  print(`${u.id}: ${u.label} → ${label}`);
}

function cmdClose(ctx, args) {
  const root = ctx.root();
  const u = findUnit(root, args._[0]);
  const problems = gateProblems(root, u, 'closed');
  if (args.scrap) {
    if (!args.decision) problems.push('scrapping needs --decision D-… recording why');
    else if (!root.records.some((r) => r.kind === 'decision' && r.id === args.decision)) problems.push(`decision ${args.decision} not found`);
  }
  if (problems.length) die(`cannot close ${show(u)}:\n  ✗ ${problems.join('\n  ✗ ')}`);
  fs.rmSync(u.dir, { recursive: true });
  print(`deleted ${rel(ctx.top, u.dir)}/ — stage it in the closing commit, e.g.:\n`);
  print(`  ${u.type} ${u.name}: ${args.scrap ? 'scrap' : 'finalize'}\n`);
  print(`  Work: ${u.id}`);
  if (args.scrap) print(`  Decision: ${args.decision}`);
}

function cmdRecord(ctx, args) {
  const [kind, ...words] = args._;
  const spec = RECORDS[kind] ?? die(`kind must be one of: ${Object.keys(RECORDS).join(', ')}`);
  const title = words.join(' ').trim() || die('a title is required');
  const root = ctx.root();
  const id = newIdent(spec.prefix);
  const file = path.join(root.dir, spec.dir, `${id}-${slugify(title)}.md`);
  const readIf = args['read-if']?.length ? args['read-if'] : ['TODO: when should a future reader load this?'];
  const supersedes = (args.supersedes ?? '').split(',').map((s) => s.trim()).filter(Boolean);
  const old = supersedes.map((s) => {
    const r = findRecord(root, s);
    if (r.kind !== kind) die(`${s} is not a ${kind}`);
    return r;
  });
  const fm = {
    decision: { status: 'accepted', date: today(), read_if: readIf, refs: args.ref ?? [], supersedes: supersedes.length ? supersedes : undefined },
    learning: { date: today(), read_if: readIf, refs: args.ref ?? [] },
    backlog: { created: today() },
  }[kind];
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, dumpDoc(fm, template(`${kind}.md`, { id, title, date: today() })));
  for (const r of old) fs.rmSync(r.file);
  print(`created ${rel(ctx.top, file)}`);
  if (old.length) {
    print(`deleted ${old.map((r) => r.id).join(', ')} — add to the commit message:`);
    for (const r of old) print(`  Supersedes: ${r.id}`);
  }
}

function checkRef(ref, base, top) {
  const i = ref.indexOf('#');
  const p = i < 0 ? ref : ref.slice(0, i);
  const sym = i < 0 ? '' : ref.slice(i + 1);
  const abs = p.startsWith('/') ? path.join(top, p) : path.join(base, p);
  if (!fs.existsSync(abs)) return `ref ${ref}: file not found`;
  if (!sym) return null;
  if (fs.statSync(abs).isDirectory()) return `ref ${ref}: symbol given for a directory`;
  const text = fs.readFileSync(abs, 'utf8');
  for (const part of sym.split(/::|\./).filter(Boolean)) {
    const esc = part.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    if (!new RegExp(`(^|[^\\w$])${esc}($|[^\\w$])`).test(text)) return `ref ${ref}: "${part}" not found in ${p}`;
  }
  return null;
}

function stagedFiles(top) {
  return tryGit(['diff', '--cached', '--name-only', '-z'], top).split('\0').filter(Boolean);
}

// Each staged file belongs to the deepest .work root whose project dir contains it.
function owningRoot(roots, top, file) {
  let best = null;
  for (const r of roots) {
    const baseRel = rel(top, r.base);
    if ((baseRel === '' || file.startsWith(baseRel + '/')) && (!best || r.base.length > best.base.length)) best = r;
  }
  return best;
}

function cmdCheck(ctx, args) {
  const roots = allRoots(ctx.top).map(loadRoot);
  const errors = [];
  const warns = [];
  for (const root of roots) {
    const where = rel(ctx.top, root.dir);
    for (const u of root.units) {
      const at = `${where}/${u.label} ${u.id}`;
      for (const p of u.problems) errors.push(`${at}: ${p}`);
      if (!u.fm) continue;
      if (!PHASES.includes(u.fm.phase)) errors.push(`${at}: phase "${u.fm.phase}" invalid`);
      const parent = parentOf(u);
      const p = parent && root.units.find((x) => x.id === parent);
      if (parent && !p) errors.push(`${at}: parent ${parent} does not exist`);
      else if (p && rank(p.type) >= rank(u.type)) errors.push(`${at}: parent ${p.label} is not a higher level`);
      if (u.fm.phase !== 'initialize') {
        if (!list(u.fm.success_criteria).length) errors.push(`${at}: success_criteria empty past initialize`);
        if (!list(u.fm.owner).length) errors.push(`${at}: owner empty past initialize`);
      }
    }
    const seen = new Map();
    for (const r of root.records) {
      const at = rel(ctx.top, r.file);
      for (const p of r.problems) errors.push(`${at}: ${p}`);
      if (r.id) {
        if (seen.has(r.id)) errors.push(`${at}: duplicate id ${r.id} (also ${seen.get(r.id)})`);
        seen.set(r.id, at);
      }
      if (!titleOf(r.body)) warns.push(`${at}: no "# title" heading`);
      if (!r.spec.durable || !r.fm) continue;
      if (!list(r.fm.read_if).length) errors.push(`${at}: read_if is empty`);
      for (const ref of list(r.fm.refs)) {
        const bad = checkRef(ref, root.base, ctx.top);
        if (bad) errors.push(`${at}: ${bad}`);
      }
      // Durable docs hold only why + cues; what/how lives in code and drifts if copied here.
      if (/^\s*(```|~~~)/m.test(r.body)) warns.push(`${at}: code block in a durable doc — point at code via refs instead`);
      if (/^\s*1[.)] .*\n\s*2[.)] .*\n\s*3[.)] /m.test(r.body)) warns.push(`${at}: step-by-step list in a durable doc — that is "how", which belongs in code`);
      if (/^TODO\b/m.test(r.body)) warns.push(`${at}: unfilled TODO`);
    }
  }

  if (args.staged) {
    const staged = stagedFiles(ctx.top);
    for (const root of roots) {
      const rootRel = rel(ctx.top, root.dir);
      if (!root.units.some((u) => u.fm?.phase === 'execute')) continue;
      const mine = staged.filter((f) => owningRoot(roots, ctx.top, f) === root);
      const code = mine.some((f) => !f.startsWith(rootRel + '/'));
      const state = mine.some((f) => f.startsWith(rootRel + '/') && f.endsWith('/STATE.md'));
      if (code && !state) (STRICT ? errors : warns).push(`${rootRel}: code changed under an executing unit but no STATE.md is staged — keep docs current in every commit`);
    }
  }

  for (const w of warns) print(`warn  ${w}`);
  for (const e of errors) print(`error ${e}`);
  if (!errors.length && !warns.length) print(`ok (${roots.length} root${roots.length === 1 ? '' : 's'})`);
  if (errors.length && (!args.hook || STRICT)) process.exitCode = 1;
}

const FIND_HELP = `usage: find <words…> [--backlog] [--json]

Lists the decisions and learnings (every .work/ root in the repo) whose read_if cues or title
match the words, best first. --backlog also searches backlog items. --json is for agents.`;

function cmdFind(ctx, args) {
  if (args.help || args._.includes('-h')) return print(FIND_HELP);
  const query = args._.join(' ').trim();
  if (!query) die(FIND_HELP);
  const kinds = new Set(['decision', 'learning', ...(args.backlog ? ['backlog'] : [])]);
  const records = allRoots(ctx.top).flatMap((dir) => loadRoot(dir).records
    .filter((r) => kinds.has(r.kind) && r.id && r.fm)
    .map((r) => ({ id: r.id, kind: r.kind, root: rel(ctx.top, dir), title: titleOf(r.body).replace(RECORD_ID_PREFIX_RE, ''), readIf: list(r.fm.read_if) })));
  const hits = findRecords(records, query);
  if (args.json) return print(JSON.stringify(hits, null, 2));
  if (!hits.length) return print(`no decisions or learnings match "${query}"`);
  for (const h of hits) {
    print(`${h.id}  ${h.title}`);
    for (const cue of h.cues) print(`    read if: ${cue}`);
  }
}

function cmdCheckMsg(ctx, args) {
  const file = args._[0] ?? die('usage: check-msg <commit-msg-file>');
  const msg = fs.readFileSync(path.resolve(ctx.cwd, file), 'utf8').replace(/^#.*$/gm, '');
  const roots = allRoots(ctx.top).map(loadRoot);
  const touched = new Set(stagedFiles(ctx.top).map((f) => owningRoot(roots, ctx.top, f)).filter(Boolean));
  const active = [...touched].some((r) => r.units.length);
  const trailers = [...msg.matchAll(/^Work:\s*(\S+)\s*$/gm)].map((m) => m[1]);
  const out = [];
  if (active && !trailers.length) out.push('no "Work: U-…" trailer, but staged changes fall under active units');
  for (const t of trailers) {
    if (!UNIT_ID_RE.test(t)) out.push(`trailer "Work: ${t}" is not a unit id (U-<16 base32 chars>)`);
  }
  for (const o of out) print(`${STRICT ? 'error' : 'warn '} ${o}`);
  if (out.length && STRICT) process.exitCode = 1;
}

function cmdDig(ctx, args) {
  const id = args._[0] ?? die('usage: dig <U-… | D-… | L-… | B-…>');
  const root = ctx.root();
  const rootRel = rel(ctx.top, root.dir);
  const rec = id.match(RECORD_ID_RE);
  let pathspec;
  let matches;
  if (rec) {
    const spec = Object.values(RECORDS).find((s) => s.prefix === rec[1]);
    pathspec = `${rootRel}/${spec.dir}/`;
    matches = (f) => path.basename(f).startsWith(`${id}-`) || path.basename(f) === `${id}.md`;
  } else {
    if (!UNIT_ID_RE.test(id)) die('dig takes an id (U-…, D-…, L-…, B-…); names are reused, ids are not');
    pathspec = `${rootRel}/`;
    // Any type dir: the unit may have been rescoped between commits.
    matches = (f) => f.split('/').some((seg) => seg.startsWith(`${id}-`));
  }

  const trail = tryGit(['log', '--all', '--date=short', '--format=%h %ad %s', '-E', `--grep=^(Work|Supersedes|Decision): ${id}$`], ctx.top).trim();
  if (trail) print(`commits with a trailer for ${id}:\n${trail.replace(/^/gm, '  ')}\n`);

  const log = tryGit(['log', '--all', '--no-renames', '--diff-filter=D', '--format=@@%H %h %ad', '--date=short', '--name-only', '--', pathspec], ctx.top);
  const deletions = log.split('@@').filter(Boolean).map((block) => {
    const [head, ...files] = block.trim().split('\n');
    const [full, short, date] = head.split(' ');
    return { full, short, date, files: files.filter((f) => f && matches(f)) };
  }).filter((d) => d.files.length);
  if (!deletions.length) {
    if (!trail) die(`no history found for ${id} under ${rootRel}`);
    return;
  }
  const [last, ...older] = deletions;
  print(`deleted in ${last.short} (${last.date}); last version from ${last.short}^:\n`);
  for (const f of last.files) {
    print(`===== ${f}`);
    print(tryGit(['show', `${last.full}^:${f}`], ctx.top));
  }
  if (older.length) print(`earlier deletions: ${older.map((d) => `${d.short} (${d.date})`).join(', ')}`);
}

function cmdHooks(ctx, args) {
  if (args._[0] !== 'install') die('usage: hooks install');
  const hooksDir = path.resolve(ctx.top, git(['rev-parse', '--git-path', 'hooks'], ctx.top).trim());
  const scriptRel = rel(ctx.top, SCRIPT);
  const script = scriptRel.startsWith('..') ? JSON.stringify(SCRIPT) : `"$(git rev-parse --show-toplevel)/${scriptRel}"`;
  const guard = 'command -v node >/dev/null 2>&1 || { echo "dev-proc: node not found, skipping checks" >&2; exit 0; }';
  const hooks = {
    'pre-commit': `exec node ${script} check --staged --hook`,
    'commit-msg': `exec node ${script} check-msg "$1"`,
  };
  fs.mkdirSync(hooksDir, { recursive: true });
  for (const [name, cmd] of Object.entries(hooks)) {
    const file = path.join(hooksDir, name);
    if (fs.existsSync(file) && !fs.readFileSync(file, 'utf8').includes(HOOK_MARKER)) {
      print(`skip  ${name}: a foreign hook exists; add this line to it yourself:\n      ${cmd.replace(/^exec /, '')}`);
      continue;
    }
    fs.writeFileSync(file, `#!/bin/sh\n${HOOK_MARKER}\n${guard}\n${cmd}\n`, { mode: 0o755 });
    print(`wrote ${rel(ctx.top, file) || file}`);
  }
  print(`hooks warn by default; set DEV_PROC_STRICT=1 to make them block`);
}

const HELP = `dev-proc — units (${TYPES.join(' > ')}) moving ${PHASES.join(' → ')}

  init [dir]                               create <dir>/.work/
  <unit> is a unit id (U-…) or, for active units, its <type>/<name> label

  status [<unit>] [--json]                 tree of units, or one unit's mode + gate
  find <words…> [--backlog] [--json]       decisions and learnings whose read_if or title match what you are about to do
  new <type> <name> [--parent <unit>] [--owner a,b] [--from B-…] [--with design,plan]
  phase <unit> <phase>      [--force]      move a unit (forward moves are gated)
  rescope <unit> [--type t] [--name n] [--parent <unit>|none]
  close <unit> [--scrap --decision D-…]   delete a finalized unit's docs
  record <decision|learning|backlog> <title> [--read-if "…"]… [--ref path#symbol]… [--supersedes D-…,…]
  check [--staged]                         lint every .work/ root in the repo
  check-msg <file>                         lint a commit message's Work: trailer
  dig <U-…|D-…|L-…|B-…>                    show deleted docs from git history
  hooks install                            pre-commit + commit-msg hooks (DEV_PROC_STRICT=1 blocks)

  --root <dir>   use this .work/ instead of the nearest one above cwd`;

const COMMANDS = {
  init: cmdInit, status: cmdStatus, find: cmdFind, new: cmdNew, phase: cmdPhase, rescope: cmdRescope, close: cmdClose,
  record: cmdRecord, check: cmdCheck, 'check-msg': cmdCheckMsg, dig: cmdDig, hooks: cmdHooks,
};
const BOOLEAN = new Set(['json', 'scrap', 'staged', 'hook', 'force', 'help', 'backlog']);
const REPEATABLE = new Set(['read-if', 'ref']);

function parseArgs(argv) {
  const args = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (!a.startsWith('--')) { args._.push(a); continue; }
    let [key, val] = a.slice(2).split(/=(.*)/s);
    if (BOOLEAN.has(key)) { args[key] = true; continue; }
    if (val === undefined) val = argv[++i] ?? die(`--${key} needs a value`);
    if (REPEATABLE.has(key)) (args[key] ??= []).push(val);
    else args[key] = val;
  }
  return args;
}

function main() {
  const [cmd, ...rest] = process.argv.slice(2);
  if (!cmd || cmd === 'help' || cmd === '--help' || cmd === '-h') return print(HELP);
  const fn = COMMANDS[cmd] ?? die(`unknown command "${cmd}"\n\n${HELP}`);
  const args = parseArgs(rest);
  const cwd = process.cwd();
  const top = repoTop(cwd);
  const ctx = {
    cwd,
    top,
    root() {
      const dir = args.root ? path.resolve(cwd, args.root) : nearestRoot(cwd, top);
      if (!dir || !fs.existsSync(dir)) die('no .work/ found from here up to the repo root — run `dev-proc init`');
      return loadRoot(dir);
    },
  };
  fn(ctx, args);
}

// Piping into `head` closes stdout early; that is not an error.
process.stdout.on('error', (e) => { if (e.code === 'EPIPE') process.exit(0); throw e; });

try { main(); }
catch (e) {
  if (!(e instanceof UsageError)) throw e;
  process.stderr.write(`dev-proc: ${e.message}\n`);
  process.exitCode = 2;
}
