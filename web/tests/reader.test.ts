import { describe, it, expect, vi, afterEach } from "vitest";
import { ReaderSession } from "../src/core/session";
import {
  displayDuration,
  normalize,
  pivot,
  searchDocument,
  section,
  tokenize,
  splitSections,
  tokenIndexAtOffset,
} from "../src/core/text";
import { defaultPreferences, type Book } from "../src/core/types";

const book = (text = "One two three four five six"): Book => ({
  id: "test",
  title: "Test",
  sourceName: "test",
  format: "plainText",
  importedAt: 0,
  fingerprint: "test",
  sections: [section("First", text), section("Second", "Seven eight nine")],
  progress: { sectionIndex: 0, wordIndex: 0 },
  preferences: { ...defaultPreferences, pauseOnPunctuation: false },
  isFavorite: false,
  notes: [],
});
afterEach(() => vi.useRealTimers());
describe("shared text model", () => {
  it("keeps UTF-16 ranges and filters punctuation-only tokens", () => {
    const text = normalize("  Hello\r\n café  🌿 world.\u00a0 42  ");
    const tokens = tokenize(text);
    expect(tokens.map((t) => t.text)).toEqual([
      "Hello",
      "café",
      "world.",
      "42",
    ]);
    tokens.forEach((t) => expect(text.slice(t.start, t.end)).toBe(t.text));
  });
  it("preserves opening text and heading chapter titles", () => {
    const result = splitSections(
      "Opening paragraph.\n\nChapter I\nFirst chapter.\n\nChapter II\nSecond chapter.",
      "Book",
    );
    expect(result.map((s) => s.title)).toEqual([
      "Book",
      "Chapter I",
      "Chapter II",
    ]);
    expect(result[0].text).toContain("Opening paragraph");
  });
  it("uses the native pivot letter rules", () => {
    expect(pivot("a")).toEqual(["", "a", ""]);
    expect(pivot("reader")).toEqual(["re", "a", "der"]);
    expect(pivot("understanding")).toEqual(["und", "e", "rstanding"]);
  });
  it("maps text clicks and UTF-16 offsets to shared word indices", () => {
    const tokens = tokenize("One café 🪴 three.");
    expect(tokenIndexAtOffset(tokens, 0)).toBe(0);
    expect(tokenIndexAtOffset(tokens, 6)).toBe(1);
    expect(tokenIndexAtOffset(tokens, 12)).toBe(2);
    expect(tokenIndexAtOffset(tokens, 100)).toBe(2);
    expect(tokenIndexAtOffset([], 0)).toBe(0);
  });
  it("searches case and diacritics while mapping to the shared token space", () => {
    const sections = [section("First", "A café and a CAFÉ. Then 🪴 résumé.")];
    const matches = searchDocument(sections, "cafe");
    expect(matches.map((m) => m.wordIndex)).toEqual([1, 4]);
    expect(matches.map((m) => m.match)).toEqual(["café", "CAFÉ"]);
    expect(searchDocument(sections, "resume")[0].wordIndex).toBe(6);
  });
  it("caps search results at 500", () =>
    expect(
      searchDocument([section("Many", "word ".repeat(600))], "word"),
    ).toHaveLength(500));
});
describe("playback timing", () => {
  it("matches native punctuation, warm-up and long-word durations", () => {
    const p = { ...defaultPreferences, wordsPerMinute: 300 };
    expect(displayDuration(["word"], p)).toBe(200);
    expect(displayDuration(["word."], p)).toBe(360);
    expect(displayDuration(["word,"], p)).toBe(270);
    expect(displayDuration(["one", "two"], p)).toBe(400);
    expect(displayDuration(["word"], { ...p, rampUpSeconds: 4 }, 0)).toBe(400);
    expect(displayDuration(["word"], { ...p, rampUpSeconds: 4 }, 4000)).toBe(
      200,
    );
    expect(
      displayDuration(["a".repeat(30)], { ...p, pauseOnLongWords: true }),
    ).toBe(320);
  });
  it("counts words only after their display finishes and stops after disposal", () => {
    vi.useFakeTimers();
    const b = book();
    b.preferences.wordsPerMinute = 300;
    const session = new ReaderSession(b);
    const segment = vi.fn();
    session.onSegment = segment;
    session.play();
    vi.advanceTimersByTime(450);
    session.pause();
    expect(session.getSnapshot().wordIndex).toBe(2);
    expect(segment.mock.calls[0][0]).toBe(2);
    session.play();
    session.dispose();
    vi.advanceTimersByTime(10000);
    expect(session.getSnapshot().playing).toBe(false);
    expect(session.getSnapshot().wordIndex).toBe(2);
  });
  it("transitions between chapters and marks the document complete", () => {
    vi.useFakeTimers();
    const b = book("One two");
    b.preferences.wordsPerMinute = 300;
    const session = new ReaderSession(b);
    const segment = vi.fn();
    session.onSegment = segment;
    session.play();
    vi.advanceTimersByTime(1000);
    expect(session.atEnd).toBe(true);
    expect(session.getSnapshot().playing).toBe(false);
    expect(segment.mock.calls[0][0]).toBe(5);
    session.dispose();
  });
  it("rewinds after playback pauses and clears rewind after seeking", () => {
    vi.useFakeTimers();
    const b = book();
    b.preferences.wordsPerMinute = 300;
    b.preferences.resumeRewindWords = 2;
    const session = new ReaderSession(b);
    session.play();
    vi.advanceTimersByTime(650);
    session.pause();
    expect(session.getSnapshot().wordIndex).toBe(3);
    session.play();
    expect(session.getSnapshot().wordIndex).toBe(1);
    session.pause();
    session.seek(0, 4);
    session.play();
    expect(session.getSnapshot().wordIndex).toBe(4);
    session.dispose();
  });
});
