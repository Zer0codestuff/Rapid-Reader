import { clampPreferences, type Preferences, type Section } from "./types";

export interface Token {
  text: string;
  start: number;
  end: number;
}
export function normalize(text: string) {
  return text
    .replace(/\r\n?/g, "\n")
    .replace(/[\u00a0\ufffc\u200b]/g, " ")
    .split("\n")
    .map((line) => line.trim())
    .join("\n")
    .replace(/[ \t]{2,}/g, " ")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}
export function tokenize(text: string): Token[] {
  return [...text.matchAll(/\S+/gu)]
    .filter((m) => /[\p{L}\p{N}]/u.test(m[0]))
    .map((m) => ({ text: m[0], start: m.index!, end: m.index! + m[0].length }));
}
export function tokenIndexAtOffset(tokens: Token[], offset: number) {
  let lo = 0,
    hi = tokens.length;
  while (lo < hi) {
    const mid = (lo + hi) >> 1;
    if (tokens[mid].end <= offset) lo = mid + 1;
    else hi = mid;
  }
  return Math.min(lo, Math.max(0, tokens.length - 1));
}
export function section(title: string, text: string): Section {
  const cleaned = normalize(text);
  return {
    id: crypto.randomUUID(),
    title: title.trim() || "Untitled section",
    text: cleaned,
    wordCount: tokenize(cleaned).length,
  };
}
export function splitSections(text: string, title: string): Section[] {
  const cleaned = normalize(text);
  const lines = cleaned.split("\n");
  const result: Section[] = [];
  let currentTitle = title;
  let current: string[] = [];
  for (const line of lines) {
    if (
      line.length <= 90 &&
      /^(#{1,6}\s+|(?:chapter|section|part|book)\s+(?:[0-9ivxlcdm]+|[a-z])(?:[:.\-\s]|$))/i.test(
        line,
      )
    ) {
      if (current.length)
        result.push(section(currentTitle, current.join("\n")));
      currentTitle = line.replace(/^#{1,6}\s*/, "");
      current = [];
    } else current.push(line);
  }
  if (current.length) result.push(section(currentTitle, current.join("\n")));
  const readable = result.filter((s) => s.wordCount > 0);
  if (readable.length > 1) return readable;
  const tokens = tokenize(cleaned);
  if (tokens.length <= 1600) return [section(title, cleaned)];
  const parts: Section[] = [];
  for (let i = 0; i < tokens.length; i += 1200) {
    const end = tokens[Math.min(i + 1199, tokens.length - 1)].end;
    parts.push(
      section(`Part ${parts.length + 1}`, cleaned.slice(tokens[i].start, end)),
    );
  }
  return parts;
}
export function pivot(word: string): [string, string, string] {
  const chars = Array.from(word);
  const index =
    chars.length <= 1
      ? 0
      : chars.length <= 5
        ? 1
        : chars.length <= 9
          ? 2
          : chars.length <= 13
            ? 3
            : 4;
  return [
    chars.slice(0, index).join(""),
    chars[index] ?? "",
    chars.slice(index + 1).join(""),
  ];
}
export function displayDuration(
  words: string[],
  preferences: Preferences,
  elapsed = Infinity,
) {
  const p = clampPreferences(preferences);
  let duration = (60000 * Math.max(1, words.length)) / p.wordsPerMinute;
  const ending = (words.at(-1) ?? "").replace(/["'”’\])}]+$/u, "");
  if (p.pauseOnPunctuation)
    duration *= /[.!?]$/.test(ending) ? 1.8 : /[,;:]$/.test(ending) ? 1.35 : 1;
  if (p.pauseOnLongWords)
    duration *=
      1 +
      Math.min(
        0.6,
        Math.max(
          0,
          Math.max(0, ...words.map((w) => Array.from(w).length)) - 8,
        ) * 0.05,
      );
  if (p.rampUpSeconds > 0)
    duration /=
      0.5 + 0.5 * Math.min(1, Math.max(0, elapsed / (p.rampUpSeconds * 1000)));
  return duration;
}
export function fold(text: string) {
  return text.normalize("NFD").replace(/\p{M}/gu, "").toLocaleLowerCase("en");
}
export interface SearchMatch {
  sectionIndex: number;
  wordIndex: number;
  before: string;
  match: string;
  after: string;
}
export function searchDocument(
  sections: Section[],
  query: string,
  limit = 500,
): SearchMatch[] {
  const needle = fold(query.trim());
  if (!needle) return [];
  const matches: SearchMatch[] = [];
  for (let sectionIndex = 0; sectionIndex < sections.length; sectionIndex++) {
    const text = sections[sectionIndex].text;
    const chars = Array.from(text);
    let folded = "";
    const offsets: number[] = [];
    let utf16 = 0;
    for (const char of chars) {
      const normalized = fold(char);
      folded += normalized;
      for (let i = 0; i < normalized.length; i++) offsets.push(utf16);
      utf16 += char.length;
    }
    offsets.push(text.length);
    const tokens = tokenize(text);
    let cursor = 0;
    while (
      (cursor = folded.indexOf(needle, cursor)) !== -1 &&
      matches.length < limit
    ) {
      const start = offsets[cursor],
        end = offsets[cursor + needle.length] ?? text.length;
      matches.push({
        sectionIndex,
        wordIndex: tokenIndexAtOffset(tokens, start),
        before: text.slice(Math.max(0, start - 48), start),
        match: text.slice(start, end),
        after: text.slice(end, end + 70),
      });
      cursor += Math.max(needle.length, 1);
    }
    if (matches.length >= limit) break;
  }
  return matches;
}
