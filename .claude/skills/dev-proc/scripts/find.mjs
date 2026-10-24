// Ranks durable records (decisions, learnings) against a free-text "what I am about to do" query.
// A query token matches a read_if cue or the title after light normalisation (see `stem`).
// Records are { id, kind, title, readIf: string[] }.

const STOPWORDS = new Set((
  'a an the and or but to of in on at for from by with without into about as is are was be been being it its this that these those '
  + 'i me my we our you your when before after while how what why which do does doing done not no'
).split(' '));

// Ref-style cues (`crates/sim/src/rng.rs#Rng`) locate code rather than describe a reason to read,
// and their path segments ("sim", "src") would match nearly every record.
const isRefCue = (cue) => !/\s/.test(cue) && /[/#]/.test(cue);

// Words that name one concept but do not share a stem. Keep this short and justified.
const SYNONYMS = { rng: 'random' };

// Light stemming: US spelling, one suffix, a trailing "e", a doubled final consonant.
// "optimising", "optimizes" and "optimize" all become "optimiz"; "changing" and "change" become "chang".
export function stem(word) {
  let w = word.toLowerCase().replace(/colour/g, 'color');
  if (w.length > 5) w = w.replace(/is(e|ed|es|ing)$/, 'iz$1');
  for (const suffix of ['ness', 'ing', 'ed', 'es', 's']) {
    if (w.endsWith(suffix) && !(suffix === 's' && w.endsWith('ss')) && w.length - suffix.length >= 3) {
      w = w.slice(0, -suffix.length);
      break;
    }
  }
  w = w.replace(/e$/, '').replace(/([^aeiou])\1$/, '$1');
  return SYNONYMS[w] ?? w;
}

export function tokenize(text) {
  const tokens = text.toLowerCase().split(/[^a-z0-9]+/).filter((t) => t && !STOPWORDS.has(t)).map(stem);
  return [...new Set(tokens)];
}

const TITLE_WEIGHT = 1;
const CUE_WEIGHT = 2;
const COMMON_SHARE = 0.25;

// Returns matching records, best first: [{ ...record, cues, matched, score }].
// Each distinct query token counts once; a read_if hit is worth more than a title hit, and a
// token matching few records is worth more than one matching many (weight ln(N / records hit)).
// A token that hits more than a quarter of the records ("changing", "sim") only adds noise, so it
// is ignored unless every query token is that common.
export function findRecords(records, query) {
  const docs = records.map((r) => ({
    r,
    title: new Set(tokenize(r.title)),
    cues: r.readIf.filter((c) => !isRefCue(c)).map((cue) => ({ cue, tokens: new Set(tokenize(cue)) })),
  }));
  const inCue = (d, t) => d.cues.some((c) => c.tokens.has(t));
  const df = (t) => docs.filter((d) => d.title.has(t) || inCue(d, t)).length;

  let tokens = tokenize(query).map((t) => ({ t, df: df(t) })).filter((x) => x.df > 0);
  const rare = tokens.filter((x) => x.df <= COMMON_SHARE * docs.length);
  if (rare.length) tokens = rare;

  const hits = [];
  for (const d of docs) {
    let score = 0;
    const matched = [];
    for (const { t, df: n } of tokens) {
      const cue = inCue(d, t);
      if (!cue && !d.title.has(t)) continue;
      score += (cue ? CUE_WEIGHT : TITLE_WEIGHT) * Math.log(docs.length / n);
      matched.push(t);
    }
    if (!matched.length) continue;
    const cues = d.cues.filter((c) => matched.some((t) => c.tokens.has(t))).map((c) => c.cue);
    hits.push({ ...d.r, cues, matched, score: Math.round(score * 100) / 100 });
  }
  return hits.sort((a, b) => b.score - a.score || (a.id < b.id ? -1 : 1));
}
