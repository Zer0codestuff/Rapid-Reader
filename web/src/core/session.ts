import { displayDuration, tokenize, type Token } from "./text";
import {
  clamp,
  clampPreferences,
  type Book,
  type Preferences,
  type Progress,
} from "./types";

export interface SessionState extends Progress {
  playing: boolean;
  preferences: Preferences;
}
export class ReaderSession {
  readonly book: Book;
  private state: SessionState;
  private listeners = new Set<() => void>();
  private cache = new Map<number, Token[]>();
  private timer: ReturnType<typeof setTimeout> | undefined;
  private startedAt = 0;
  private segmentWords = 0;
  private rewindOnResume = false;
  private deadline = 0;
  private lastReport = 0;
  onProgress?: (progress: Progress, preferences: Preferences) => void;
  onSegment?: (words: number, seconds: number, startedAt: number) => void;

  constructor(book: Book) {
    this.book = book;
    const sectionIndex = clamp(
      book.progress.sectionIndex,
      0,
      Math.max(0, book.sections.length - 1),
    );
    this.state = {
      sectionIndex,
      wordIndex: clamp(
        book.progress.wordIndex,
        0,
        this.tokens(sectionIndex).length,
      ),
      playing: false,
      preferences: clampPreferences(book.preferences),
    };
  }
  getSnapshot = () => this.state;
  subscribe = (listener: () => void) => {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  };
  private update(value: Partial<SessionState>) {
    this.state = { ...this.state, ...value };
    this.listeners.forEach((fn) => fn());
  }
  tokens(index = this.state?.sectionIndex ?? 0): Token[] {
    if (!this.cache.has(index))
      this.cache.set(index, tokenize(this.book.sections[index]?.text ?? ""));
    return this.cache.get(index)!;
  }
  get displayIndex() {
    return clamp(
      this.state.wordIndex,
      0,
      Math.max(0, this.tokens().length - 1),
    );
  }
  get displayWords() {
    return this.tokens()
      .slice(
        this.displayIndex,
        this.displayIndex + this.state.preferences.chunkSize,
      )
      .map((t) => t.text);
  }
  get atEnd() {
    return (
      this.state.sectionIndex >= this.book.sections.length - 1 &&
      this.state.wordIndex >= this.tokens().length
    );
  }
  toggle = () => {
    this.state.playing ? this.pause() : this.play();
  };
  play = () => {
    if (this.state.playing) return;
    if (this.atEnd) this.seek(0, 0);
    else if (this.rewindOnResume)
      this.update({
        wordIndex: Math.max(
          0,
          this.state.wordIndex - this.state.preferences.resumeRewindWords,
        ),
      });
    this.rewindOnResume = false;
    while (
      !this.tokens().length &&
      this.state.sectionIndex + 1 < this.book.sections.length
    )
      this.update({ sectionIndex: this.state.sectionIndex + 1, wordIndex: 0 });
    if (!this.tokens().length) return;
    this.startedAt = performance.now();
    this.segmentWords = 0;
    this.deadline = this.startedAt;
    this.update({ playing: true });
    this.schedule();
  };
  private schedule() {
    const now = performance.now();
    const duration = displayDuration(
      this.displayWords,
      this.state.preferences,
      now - this.startedAt,
    );
    if (now - this.deadline > 1000) this.deadline = now;
    this.deadline += duration;
    this.timer = setTimeout(
      () => {
        if (!this.state.playing) return;
        this.segmentWords += this.displayWords.length;
        if (!this.advance(true)) {
          this.pause();
          return;
        }
        this.report(false);
        this.schedule();
      },
      Math.max(0, this.deadline - now),
    );
  }
  pause = () => {
    if (this.timer !== undefined) clearTimeout(this.timer);
    this.timer = undefined;
    if (this.state.playing) {
      this.rewindOnResume = true;
      this.onSegment?.(
        this.segmentWords,
        (performance.now() - this.startedAt) / 1000,
        Date.now() - (performance.now() - this.startedAt),
      );
    }
    this.segmentWords = 0;
    this.update({ playing: false });
    this.report(true);
  };
  private advance(forward: boolean) {
    const { sectionIndex, wordIndex, preferences } = this.state;
    if (forward) {
      if (wordIndex + preferences.chunkSize < this.tokens().length)
        this.update({ wordIndex: wordIndex + preferences.chunkSize });
      else if (sectionIndex + 1 < this.book.sections.length)
        this.update({ sectionIndex: sectionIndex + 1, wordIndex: 0 });
      else {
        this.update({ wordIndex: this.tokens().length });
        return false;
      }
    } else {
      if (wordIndex >= preferences.chunkSize)
        this.update({
          wordIndex: Math.min(
            wordIndex - preferences.chunkSize,
            Math.max(0, this.tokens().length - 1),
          ),
        });
      else if (sectionIndex > 0)
        this.update({
          sectionIndex: sectionIndex - 1,
          wordIndex: Math.max(0, this.tokens(sectionIndex - 1).length - 1),
        });
      else this.update({ wordIndex: 0 });
    }
    return true;
  }
  step = (forward: boolean) => {
    this.pause();
    this.rewindOnResume = false;
    this.advance(forward);
    this.report(true);
  };
  seek = (sectionIndex: number, wordIndex = 0) => {
    this.pause();
    this.rewindOnResume = false;
    sectionIndex = clamp(
      sectionIndex,
      0,
      Math.max(0, this.book.sections.length - 1),
    );
    this.update({
      sectionIndex,
      wordIndex: clamp(
        wordIndex,
        0,
        Math.max(0, this.tokens(sectionIndex).length - 1),
      ),
    });
    this.report(true);
  };
  setPreferences = (value: Partial<Preferences>) => {
    this.update({
      preferences: clampPreferences({ ...this.state.preferences, ...value }),
    });
    this.report(true);
  };
  private report(force: boolean) {
    const now = performance.now();
    if (!force && now - this.lastReport < 1000) return;
    this.lastReport = now;
    this.onProgress?.(
      {
        sectionIndex: this.state.sectionIndex,
        wordIndex: this.state.wordIndex,
      },
      this.state.preferences,
    );
  }
  dispose() {
    this.pause();
    this.listeners.clear();
  }
}
