import { openDB, type DBSchema } from "idb";
import { normalize, tokenize } from "./text";
import {
  clamp,
  clampPreferences,
  defaultSettings,
  localDate,
  metadata,
  type Book,
  type BookMetadata,
  type DailyStats,
  type ImportedDocument,
  type Settings,
} from "./types";

interface ReaderDB extends DBSchema {
  books: { key: string; value: BookMetadata };
  contents: { key: string; value: Book["sections"] };
  settings: { key: string; value: Settings };
  statistics: { key: string; value: DailyStats };
  backups: {
    key: string;
    value: { createdAt: number; data: unknown; reason: string };
  };
}
const database = () =>
  openDB<ReaderDB>("rapid-reader", 1, {
    upgrade(db) {
      db.createObjectStore("books", { keyPath: "id" });
      db.createObjectStore("contents");
      db.createObjectStore("settings");
      db.createObjectStore("statistics", { keyPath: "date" });
      db.createObjectStore("backups");
    },
  });

async function fingerprint(sections: Book["sections"]) {
  const bytes = new TextEncoder().encode(
    sections.map((s) => normalize(s.text)).join("\n\u0000\n"),
  );
  return Array.from(
    new Uint8Array(await crypto.subtle.digest("SHA-256", bytes)),
  )
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}
export async function loadLibrary(): Promise<BookMetadata[]> {
  const db = await database();
  const values = await db.getAll("books");
  const valid: BookMetadata[] = [];
  for (const book of values) {
    if (
      book &&
      typeof book.id === "string" &&
      typeof book.title === "string" &&
      Array.isArray(book.sections) &&
      book.progress
    ) {
      valid.push({
        ...book,
        notes: book.notes ?? [],
        preferences: clampPreferences(book.preferences),
      });
    } else {
      await db.put(
        "backups",
        {
          createdAt: Date.now(),
          data: book,
          reason: "Unreadable library entry",
        },
        crypto.randomUUID(),
      );
      throw new Error(
        "A library entry could not be read. Its data was backed up and has not been overwritten. Export a backup from Settings before making changes.",
      );
    }
  }
  return valid.sort(
    (a, b) => (b.lastReadAt ?? b.importedAt) - (a.lastReadAt ?? a.importedAt),
  );
}
export async function loadBook(id: string): Promise<Book> {
  const db = await database();
  const tx = db.transaction(["books", "contents"], "readonly");
  const [book, sections] = await Promise.all([
    tx.objectStore("books").get(id),
    tx.objectStore("contents").get(id),
  ]);
  if (!book || !sections || !sections.every((s) => typeof s.text === "string"))
    throw new Error(
      "This document could not be read. Its saved data has been kept.",
    );
  return {
    ...book,
    sections,
    notes: book.notes ?? [],
    preferences: clampPreferences(book.preferences),
  };
}
export async function importDocument(
  doc: ImportedDocument,
  settings: Settings,
) {
  if (!doc.sections.some((s) => s.wordCount > 0))
    throw new Error(
      "This document contains no readable text. Scanned PDFs need OCR before importing.",
    );
  const hash = await fingerprint(doc.sections);
  const db = await database();
  const books = await db.getAll("books");
  const existing = books.find((b) => b.fingerprint === hash);
  if (existing) return { book: await loadBook(existing.id), duplicate: true };
  const book: Book = {
    ...doc,
    id: crypto.randomUUID(),
    importedAt: Date.now(),
    fingerprint: hash,
    progress: { sectionIndex: 0, wordIndex: 0 },
    preferences: { ...settings.defaults },
    isFavorite: false,
    notes: [],
  };
  const tx = db.transaction(["books", "contents"], "readwrite");
  await Promise.all([
    tx.objectStore("books").put(metadata(book)),
    tx.objectStore("contents").put(book.sections, book.id),
  ]);
  await tx.done;
  return { book, duplicate: false };
}
export async function saveBook(book: Book) {
  const db = await database();
  await db.put("books", metadata(book));
}
export async function deleteBook(id: string) {
  const db = await database();
  const tx = db.transaction(["books", "contents"], "readwrite");
  await Promise.all([
    tx.objectStore("books").delete(id),
    tx.objectStore("contents").delete(id),
  ]);
  await tx.done;
}
export async function loadSettings() {
  const db = await database();
  const s = await db.get("settings", "main");
  return {
    ...defaultSettings,
    ...s,
    theme: ["system", "light", "dark", "sepia"].includes(s?.theme ?? "")
      ? s!.theme
      : "system",
    defaults: clampPreferences(s?.defaults ?? {}),
  } as Settings;
}
export async function saveSettings(settings: Settings) {
  const db = await database();
  await db.put("settings", settings, "main");
}
export async function loadStats() {
  const db = await database();
  return db.getAll("statistics");
}
export async function recordStats(
  words: number,
  seconds: number,
  startedAt: number,
) {
  if (words <= 0 || seconds <= 0 || !Number.isFinite(seconds)) return;
  const db = await database();
  const tx = db.transaction("statistics", "readwrite");
  const date = localDate(startedAt);
  const old = (await tx.store.get(date)) ?? { date, words: 0, seconds: 0 };
  await tx.store.put({
    date,
    words: old.words + words,
    seconds: old.seconds + seconds,
  });
  await tx.done;
}
export async function exportLibrary() {
  const db = await database();
  const [books, settings, statistics, backups] = await Promise.all([
    db.getAll("books"),
    loadSettings(),
    db.getAll("statistics"),
    db.getAll("backups"),
  ]);
  const documents = await Promise.all(
    books.map(async (b) => ({
      ...b,
      sections: await db.get("contents", b.id),
    })),
  );
  return {
    version: 1,
    app: "Rapid Reader",
    exportedAt: new Date().toISOString(),
    books: documents,
    settings,
    statistics,
    backups,
  };
}
function safeCover(value: unknown) {
  return typeof value === "string" &&
    /^data:image\/(png|jpeg|webp|gif);base64,[a-z\d+/=\s]+$/i.test(value) &&
    value.length < 15_000_000
    ? value
    : undefined;
}
export async function restoreLibrary(value: unknown): Promise<number> {
  if (!value || typeof value !== "object")
    throw new Error("Choose a Rapid Reader JSON backup.");
  const data = value as {
    version?: unknown;
    app?: unknown;
    books?: unknown;
    statistics?: unknown;
    settings?: Settings;
  };
  if (
    data.app !== "Rapid Reader" ||
    data.version !== 1 ||
    !Array.isArray(data.books) ||
    data.books.length > 10000
  )
    throw new Error("This is not a supported Rapid Reader backup.");
  const books: Book[] = [];
  for (const raw of data.books) {
    const b = raw as Book;
    if (
      typeof b.title !== "string" ||
      !Array.isArray(b.sections) ||
      !b.sections.length ||
      !b.sections.every(
        (s) => typeof s.text === "string" && typeof s.title === "string",
      )
    )
      throw new Error(
        "The backup contains an unreadable document. Nothing was restored.",
      );
    const sections = b.sections.map((s) => ({
      id: typeof s.id === "string" ? s.id : crypto.randomUUID(),
      title: s.title,
      text: normalize(s.text),
      wordCount: tokenize(normalize(s.text)).length,
    }));
    const sectionIndex = clamp(
      Number(b.progress?.sectionIndex) || 0,
      0,
      sections.length - 1,
    );
    books.push({
      id: typeof b.id === "string" ? b.id : crypto.randomUUID(),
      title: b.title,
      author: typeof b.author === "string" ? b.author : undefined,
      sourceName: typeof b.sourceName === "string" ? b.sourceName : b.title,
      sourceURL:
        typeof b.sourceURL === "string" && /^https?:\/\//i.test(b.sourceURL)
          ? b.sourceURL
          : undefined,
      format: [
        "epub",
        "pdf",
        "docx",
        "rtf",
        "html",
        "markdown",
        "plainText",
        "webArticle",
      ].includes(b.format)
        ? b.format
        : "plainText",
      importedAt: Number(b.importedAt) || Date.now(),
      lastReadAt: Number(b.lastReadAt) || undefined,
      sections,
      fingerprint: await fingerprint(sections),
      cover: safeCover(b.cover),
      isFavorite: b.isFavorite === true,
      preferences: clampPreferences(b.preferences ?? {}),
      progress: {
        sectionIndex,
        wordIndex: clamp(
          Number(b.progress?.wordIndex) || 0,
          0,
          sections[sectionIndex].wordCount,
        ),
      },
      notes: Array.isArray(b.notes)
        ? b.notes
            .filter((n) => typeof n.text === "string")
            .map((n) => ({
              id: typeof n.id === "string" ? n.id : crypto.randomUUID(),
              text: n.text,
              createdAt: Number(n.createdAt) || Date.now(),
              sectionIndex: clamp(
                Number(n.sectionIndex) || 0,
                0,
                sections.length - 1,
              ),
              wordIndex: Math.max(0, Number(n.wordIndex) || 0),
            }))
        : [],
    });
  }
  const db = await database();
  const existing = await db.getAll("books");
  const hashes = new Set(existing.map((b) => b.fingerprint));
  const ids = new Set(existing.map((b) => b.id));
  const additions = books.filter((b) => {
    if (hashes.has(b.fingerprint)) return false;
    hashes.add(b.fingerprint);
    return true;
  });
  const tx = db.transaction(
    ["books", "contents", "statistics", "settings"],
    "readwrite",
  );
  for (const b of additions) {
    if (ids.has(b.id)) b.id = crypto.randomUUID();
    ids.add(b.id);
    hashes.add(b.fingerprint);
    await tx.objectStore("books").put(metadata(b));
    await tx.objectStore("contents").put(b.sections, b.id);
  }
  if (Array.isArray(data.statistics))
    for (const s of data.statistics as DailyStats[]) {
      if (
        !/^\d{4}-\d{2}-\d{2}$/.test(s.date) ||
        !Number.isFinite(s.words) ||
        !Number.isFinite(s.seconds) ||
        s.words < 0 ||
        s.seconds < 0
      )
        continue;
      const old = await tx.objectStore("statistics").get(s.date);
      await tx
        .objectStore("statistics")
        .put({
          date: s.date,
          words: Math.max(old?.words ?? 0, s.words),
          seconds: Math.max(old?.seconds ?? 0, s.seconds),
        });
    }
  if (data.settings && typeof data.settings === "object") {
    const old = await tx.objectStore("settings").get("main");
    const theme = ["system", "light", "dark", "sepia"].includes(
      data.settings.theme,
    )
      ? data.settings.theme
      : "system";
    await tx.objectStore("settings").put(
      {
        theme,
        defaults: clampPreferences(data.settings.defaults ?? {}),
        mode: data.settings.mode === "text" ? "text" : "rsvp",
        selectedID:
          old?.selectedID && ids.has(old.selectedID)
            ? old.selectedID
            : data.settings.selectedID && ids.has(data.settings.selectedID)
              ? data.settings.selectedID
              : undefined,
      },
      "main",
    );
  }
  await tx.done;
  return additions.length;
}
