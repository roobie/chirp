// Parses the restricted YAML front matter used by .work/ documents.
// Supported values: strings, block lists (`- item`, always plain strings), and
// inline string lists (`[a, b]`; a scalar that both starts with `[` and ends with `]`).

const FRONT_MATTER_RE = /^---[ \t]*\r?\n([\s\S]*?)\r?\n---[ \t]*(?:\r?\n|$)/;
const KEY_RE = /^([A-Za-z_][\w-]*):(?:[ \t]+(.*))?$/;
const LIST_ITEM_RE = /^[ \t]+-[ \t]+(.*)$/;

function unquote(value) {
  const match = value.match(/^(['"])([\s\S]*)\1$/);
  return match ? match[2] : value;
}

function splitInlineList(value) {
  const content = value.slice(1, -1).trim();
  if (!content) return [];

  const items = [];
  let quote = null;
  let start = 0;

  for (let i = 0; i < content.length; i += 1) {
    const char = content[i];

    // A quote opens only at the start of an item, so `don't` is plain text.
    if ((char === '"' || char === "'") && !quote && !content.slice(start, i).trim()) quote = char;
    else if (char === quote) quote = null;
    else if (char === ',' && !quote) {
      items.push(content.slice(start, i).trim());
      start = i + 1;
    }
  }

  if (quote) throw new Error(`unterminated quote in inline list: "${value}"`);

  items.push(content.slice(start).trim());

  return items.map(unquote).filter(Boolean);
}

function parseScalar(value) {
  return value.startsWith('[') && value.endsWith(']') ? splitInlineList(value) : unquote(value);
}

export function parseDoc(text) {
  const match = text.match(FRONT_MATTER_RE);
  if (!match) return { fm: null, body: text };

  const fm = {};
  let activeListKey = null;

  for (const [index, line] of match[1].split(/\r?\n/).entries()) {
    const lineNumber = index + 1;
    const trimmed = line.trim();

    if (!trimmed || trimmed.startsWith('#')) continue;

    const listItem = line.match(LIST_ITEM_RE);
    if (listItem) {
      if (!activeListKey) {
        throw new Error(`list item without a list key at front matter line ${lineNumber}`);
      }

      fm[activeListKey].push(unquote(listItem[1].trim()));
      continue;
    }

    const keyValue = line.match(KEY_RE);
    if (!keyValue) {
      throw new Error(`unparseable front matter line ${lineNumber}: "${line}"`);
    }

    const [, key, rawValue] = keyValue;

    // `fm` is a plain object, as main's parser returned; `__proto__` would rewrite its prototype.
    if (key === '__proto__') {
      throw new Error(`reserved front matter key "${key}" at line ${lineNumber}`);
    }

    if (Object.hasOwn(fm, key)) {
      throw new Error(`duplicate front matter key "${key}" at line ${lineNumber}`);
    }

    const value = (rawValue ?? '').trim();
    fm[key] = value ? parseScalar(value) : [];
    activeListKey = Array.isArray(fm[key]) ? key : null;
  }

  return {
    fm,
    body: text.slice(match[0].length),
  };
}
