import "fake-indexeddb/auto";
import { openDB } from "idb";
import { describe, it, expect } from "vitest";
import { defaultSettings } from "../src/core/types";
import { importText } from "../src/import";
import {
  deleteBook,
  exportLibrary,
  importDocument,
  loadBook,
  loadLibrary,
  recordStats,
  loadStats,
  restoreLibrary,
  saveBook,
} from "../src/core/storage";

describe("local library transactions", () => {
  it("deduplicates content while retaining progress, notes and preferences", async () => {
    const first = await importDocument(
      importText("A unique test document with readable words."),
      defaultSettings,
    );
    first.book.progress.wordIndex = 3;
    first.book.preferences.wordsPerMinute = 525;
    first.book.notes.push({
      id: "note",
      text: "A thought",
      wordIndex: 3,
      sectionIndex: 0,
      createdAt: Date.now(),
    });
    await saveBook(first.book);
    const second = await importDocument(
      importText(
        "A unique test document with readable words.",
        "Different title",
      ),
      defaultSettings,
    );
    expect(second.duplicate).toBe(true);
    expect(second.book.id).toBe(first.book.id);
    expect(second.book.progress.wordIndex).toBe(3);
    expect(second.book.notes[0].text).toBe("A thought");
    expect(second.book.preferences.wordsPerMinute).toBe(525);
  });
  it("backs up and restores a document with content, then deletes both stores", async () => {
    const value = await importDocument(
      importText("Another distinct document for backup restoration."),
      defaultSettings,
    );
    const backup = await exportLibrary();
    await deleteBook(value.book.id);
    expect((await loadLibrary()).some((b) => b.id === value.book.id)).toBe(
      false,
    );
    expect(await restoreLibrary(backup)).toBe(1);
    expect((await loadBook(value.book.id)).sections[0].text).toContain(
      "backup restoration",
    );
    expect(await restoreLibrary(backup)).toBe(0);
  });
  it("rejects unreadable backups before writing any document", async () => {
    const before = (await loadLibrary()).length;
    await expect(
      restoreLibrary({
        app: "Rapid Reader",
        version: 1,
        books: [{ title: "Invalid", sections: null }],
      }),
    ).rejects.toThrow("unreadable");
    expect((await loadLibrary()).length).toBe(before);
  });
  it("accumulates reading statistics and ignores empty runs", async () => {
    await recordStats(10, 2, Date.now());
    await recordStats(20, 4, Date.now());
    await recordStats(0, 10, Date.now());
    const stats = await loadStats();
    expect(stats.at(-1)?.words).toBe(30);
    expect(stats.at(-1)?.seconds).toBe(6);
  });
  it("backs up unreadable metadata without removing it or its content", async () => {
    const db = await openDB("rapid-reader", 1);
    await db.put("books", { id: "corrupt", title: 42 });
    await db.put("contents", [{ text: "Preserved document data." }], "corrupt");
    await expect(loadLibrary()).rejects.toThrow("backed up");
    expect(await db.get("books", "corrupt")).toEqual({
      id: "corrupt",
      title: 42,
    });
    expect((await db.get("contents", "corrupt"))[0].text).toBe(
      "Preserved document data.",
    );
    expect((await db.getAll("backups")).length).toBeGreaterThan(0);
    await db.delete("books", "corrupt");
    await db.delete("contents", "corrupt");
    db.close();
  });
});
