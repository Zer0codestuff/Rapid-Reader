export type Theme = "system" | "light" | "dark" | "sepia";
export type Format =
  | "epub"
  | "pdf"
  | "docx"
  | "rtf"
  | "html"
  | "markdown"
  | "plainText"
  | "webArticle";

export interface Preferences {
  wordsPerMinute: number;
  fontSize: number;
  chunkSize: number;
  showContext: boolean;
  pauseOnPunctuation: boolean;
  focusMode: boolean;
  rampUpSeconds: number;
  pauseOnLongWords: boolean;
  resumeRewindWords: number;
}

export const defaultPreferences: Preferences = {
  wordsPerMinute: 350,
  fontSize: 72,
  chunkSize: 1,
  showContext: true,
  pauseOnPunctuation: true,
  focusMode: false,
  rampUpSeconds: 0,
  pauseOnLongWords: false,
  resumeRewindWords: 0,
};

export const clamp = (value: number, min: number, max: number) =>
  Math.min(max, Math.max(min, value));
export function clampPreferences(value: Partial<Preferences>): Preferences {
  const p = { ...defaultPreferences, ...value };
  const number = (v: number, fallback: number, min: number, max: number) =>
    Number.isFinite(v) ? clamp(v, min, max) : fallback;
  return {
    wordsPerMinute: Math.round(number(p.wordsPerMinute, 350, 100, 900)),
    fontSize: number(p.fontSize, 72, 42, 110),
    chunkSize: Math.round(number(p.chunkSize, 1, 1, 4)),
    showContext: typeof p.showContext === "boolean" ? p.showContext : true,
    pauseOnPunctuation:
      typeof p.pauseOnPunctuation === "boolean" ? p.pauseOnPunctuation : true,
    focusMode: typeof p.focusMode === "boolean" ? p.focusMode : false,
    rampUpSeconds: number(p.rampUpSeconds, 0, 0, 10),
    pauseOnLongWords:
      typeof p.pauseOnLongWords === "boolean" ? p.pauseOnLongWords : false,
    resumeRewindWords: Math.round(number(p.resumeRewindWords, 0, 0, 20)),
  };
}

export interface Section {
  id: string;
  title: string;
  text: string;
  wordCount: number;
}
export interface Note {
  id: string;
  sectionIndex: number;
  wordIndex: number;
  text: string;
  createdAt: number;
}
export interface Progress {
  sectionIndex: number;
  wordIndex: number;
}
export interface Book {
  id: string;
  title: string;
  author?: string;
  sourceName: string;
  sourceURL?: string;
  format: Format;
  importedAt: number;
  lastReadAt?: number;
  sections: Section[];
  progress: Progress;
  preferences: Preferences;
  isFavorite: boolean;
  notes: Note[];
  cover?: string;
  fingerprint: string;
}
export type BookMetadata = Omit<Book, "sections"> & {
  sections: Omit<Section, "text">[];
};
export interface ImportedDocument {
  title: string;
  author?: string;
  sourceName: string;
  sourceURL?: string;
  format: Format;
  sections: Section[];
  cover?: string;
}
export interface DailyStats {
  date: string;
  words: number;
  seconds: number;
}
export interface Settings {
  theme: Theme;
  defaults: Preferences;
  selectedID?: string;
  mode: "rsvp" | "text";
}
export const defaultSettings: Settings = {
  theme: "system",
  defaults: { ...defaultPreferences },
  mode: "rsvp",
};

export function metadata(book: Book): BookMetadata {
  return {
    ...book,
    sections: book.sections.map(({ id, title, wordCount }) => ({
      id,
      title,
      wordCount,
    })),
  };
}
export function totalWords(book: Pick<BookMetadata, "sections">) {
  return book.sections.reduce((n, s) => n + s.wordCount, 0);
}
export function completedWords(
  book: Pick<BookMetadata, "sections" | "progress">,
) {
  const section = clamp(
    book.progress.sectionIndex,
    0,
    Math.max(0, book.sections.length - 1),
  );
  return (
    book.sections.slice(0, section).reduce((n, s) => n + s.wordCount, 0) +
    clamp(book.progress.wordIndex, 0, book.sections[section]?.wordCount ?? 0)
  );
}
export function fraction(book: Pick<BookMetadata, "sections" | "progress">) {
  return totalWords(book) ? completedWords(book) / totalWords(book) : 0;
}
export function formatTime(seconds: number) {
  if (seconds <= 0) return "0 min";
  if (seconds < 60) return "<1 min";
  const minutes = Math.ceil(seconds / 60);
  return minutes < 60
    ? `${minutes} min`
    : `${Math.floor(minutes / 60)} hr ${minutes % 60 ? `${minutes % 60} min` : ""}`.trim();
}
export function localDate(time = Date.now()) {
  const date = new Date(time);
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`;
}
export const formatLabels: Record<Format, string> = {
  epub: "EPUB",
  pdf: "PDF",
  docx: "Word document",
  rtf: "Rich text",
  html: "HTML",
  markdown: "Markdown",
  plainText: "Text",
  webArticle: "Article",
};
