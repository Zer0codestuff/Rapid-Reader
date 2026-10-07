import {
  memo,
  useEffect,
  useMemo,
  useRef,
  useState,
  useSyncExternalStore,
  type CSSProperties,
} from "react";
import {
  PanelLeft,
  List,
  Search,
  Star,
  StickyNote,
  ChevronLeft,
  ChevronRight,
  Play,
  Pause,
  SlidersHorizontal,
  Minus,
  Plus,
  Maximize,
  Minimize,
  Check,
  BookOpen,
  RotateCcw,
  X,
} from "lucide-react";
import { ReaderSession } from "../core/session";
import {
  pivot,
  tokenIndexAtOffset,
  type SearchMatch,
  type Token,
} from "../core/text";
import {
  completedWords,
  formatTime,
  totalWords,
  type Book,
  type Note,
  type Preferences,
  type Progress,
  type Theme,
} from "../core/types";
import { IconButton, Modal } from "./primitives";
import { Options } from "./Options";

function editable(target: EventTarget | null) {
  return (
    target instanceof HTMLElement &&
    Boolean(
      target.closest(
        'input,textarea,select,button,a,[contenteditable="true"],dialog',
      ),
    )
  );
}
export function Reader({
  book,
  mode,
  onMode,
  theme,
  onTheme,
  onProgress,
  onSegment,
  onNotes,
  onFavorite,
  onLibrary,
}: {
  book: Book;
  mode: "rsvp" | "text";
  onMode: (mode: "rsvp" | "text") => void;
  theme: Theme;
  onTheme: (theme: Theme) => void;
  onProgress: (
    id: string,
    progress: Progress,
    preferences: Preferences,
  ) => void;
  onSegment: (words: number, seconds: number, startedAt: number) => void;
  onNotes: (notes: Note[]) => void;
  onFavorite: () => void;
  onLibrary: () => void;
}) {
  const session = useMemo(() => new ReaderSession(book), [book.id]);
  const state = useSyncExternalStore(session.subscribe, session.getSnapshot);
  const [panel, setPanel] = useState<
    "chapters" | "search" | "notes" | "options"
  >();
  const [chrome, setChrome] = useState(true);
  const [speedHUD, setSpeedHUD] = useState<number>();
  const [fullscreen, setFullscreen] = useState(
    Boolean(document.fullscreenElement),
  );
  const hideTimer = useRef<ReturnType<typeof setTimeout>>(undefined);
  const hudTimer = useRef<ReturnType<typeof setTimeout>>(undefined);
  const controlsRef = useRef<HTMLDivElement>(null);
  const playingRef = useRef(state.playing);
  playingRef.current = state.playing;
  const reveal = () => {
    setChrome(true);
    clearTimeout(hideTimer.current);
    if (
      playingRef.current &&
      !controlsRef.current?.matches(":hover") &&
      !controlsRef.current?.contains(document.activeElement)
    )
      hideTimer.current = setTimeout(() => setChrome(false), 2200);
  };
  useEffect(() => {
    session.onProgress = (progress, preferences) =>
      onProgress(book.id, progress, preferences);
    session.onSegment = onSegment;
  }, [session, book.id, onProgress, onSegment]);
  useEffect(() => {
    const pause = () => session.pause();
    const visibility = () => {
      if (document.hidden) pause();
    };
    const fullscreenChange = () =>
      setFullscreen(Boolean(document.fullscreenElement));
    document.addEventListener("visibilitychange", visibility);
    window.addEventListener("rapid-reader:pause", pause);
    window.addEventListener("pagehide", pause);
    window.addEventListener("beforeunload", pause);
    document.addEventListener("fullscreenchange", fullscreenChange);
    return () => {
      session.dispose();
      clearTimeout(hideTimer.current);
      clearTimeout(hudTimer.current);
      document.removeEventListener("visibilitychange", visibility);
      window.removeEventListener("rapid-reader:pause", pause);
      window.removeEventListener("pagehide", pause);
      window.removeEventListener("beforeunload", pause);
      document.removeEventListener("fullscreenchange", fullscreenChange);
    };
  }, [session]);
  useEffect(() => {
    reveal();
  }, [state.playing]);
  const openPanel = (value: typeof panel) => {
    session.pause();
    setPanel(value);
  };
  const changeSpeed = (delta: number) => {
    session.setPreferences({
      wordsPerMinute: state.preferences.wordsPerMinute + delta,
    });
    setSpeedHUD(session.getSnapshot().preferences.wordsPerMinute);
    clearTimeout(hudTimer.current);
    hudTimer.current = setTimeout(() => setSpeedHUD(undefined), 1100);
    reveal();
  };
  useEffect(() => {
    const key = (e: KeyboardEvent) => {
      if (document.querySelector("dialog[open]")) return;
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "f") {
        e.preventDefault();
        openPanel("search");
        return;
      }
      if (editable(e.target) || e.metaKey || e.ctrlKey || e.altKey) return;
      if (e.code === "Space") {
        e.preventDefault();
        session.toggle();
        reveal();
      }
      if (e.key === "ArrowLeft") {
        e.preventDefault();
        session.step(false);
        reveal();
      }
      if (e.key === "ArrowRight") {
        e.preventDefault();
        session.step(true);
        reveal();
      }
      if (e.key === "ArrowUp") {
        e.preventDefault();
        changeSpeed(25);
      }
      if (e.key === "ArrowDown") {
        e.preventDefault();
        changeSpeed(-25);
      }
    };
    window.addEventListener("keydown", key);
    return () => window.removeEventListener("keydown", key);
  });
  const current = book.sections[state.sectionIndex];
  const tokens = session.tokens();
  const count = totalWords(book);
  const complete = completedWords({ ...book, progress: state });
  const percentage = count ? Math.round((complete / count) * 100) : 0;
  const remaining =
    (Math.max(0, tokens.length - state.wordIndex) * 60) /
    state.preferences.wordsPerMinute;
  const remainingBook =
    (Math.max(0, count - complete) * 60) / state.preferences.wordsPerMinute;
  const words = session.displayWords;
  const word = words.join(" ");
  const [prefix, center, suffix] = pivot(words[0] ?? "");
  const after = [suffix, ...words.slice(1)].join(" ");
  const contextBefore = tokens
    .slice(Math.max(0, session.displayIndex - 5), session.displayIndex)
    .map((t) => t.text)
    .join(" ");
  const contextAfter = tokens
    .slice(
      session.displayIndex + words.length,
      session.displayIndex + words.length + 5,
    )
    .map((t) => t.text)
    .join(" ");
  const showContext =
    state.preferences.showContext &&
    !(state.preferences.focusMode && state.playing);
  const fullscreenToggle = async () => {
    try {
      if (document.fullscreenElement) await document.exitFullscreen();
      else await document.documentElement.requestFullscreen();
    } catch {
      /* The browser may disallow fullscreen in an embedded view. */
    }
  };
  return (
    <main
      className={`reader ${state.playing ? "is-playing" : ""}`}
      onPointerMove={reveal}
      onTouchStart={reveal}
    >
      <header className="reader-header">
        <IconButton label="Show library" onClick={onLibrary}>
          <PanelLeft size={20} />
        </IconButton>
        <div className="document-heading">
          <h1 title={book.title}>{book.title}</h1>
          <span title={current?.title}>
            {current?.title}
            <span className="heading-progress">{percentage}%</span>
          </span>
        </div>
        <div
          className="segmented reader-modes"
          role="group"
          aria-label="Reader mode"
        >
          <button
            type="button"
            aria-pressed={mode === "rsvp"}
            onClick={() => {
              session.pause();
              onMode("rsvp");
            }}
          >
            RSVP
          </button>
          <button
            type="button"
            aria-pressed={mode === "text"}
            onClick={() => {
              session.pause();
              onMode("text");
            }}
          >
            Text
          </button>
        </div>
        <div className="reader-tools">
          <IconButton label="Chapters" onClick={() => openPanel("chapters")}>
            <List size={21} />
          </IconButton>
          <IconButton
            label="Search document"
            onClick={() => openPanel("search")}
          >
            <Search size={20} />
          </IconButton>
          <IconButton
            label={
              book.isFavorite ? "Unfavorite document" : "Favorite document"
            }
            aria-pressed={book.isFavorite}
            className={book.isFavorite ? "active" : ""}
            onClick={onFavorite}
          >
            <Star size={21} fill={book.isFavorite ? "currentColor" : "none"} />
          </IconButton>
          <IconButton label="Notes" onClick={() => openPanel("notes")}>
            <StickyNote size={20} />
            {book.notes.length > 0 && <span className="note-dot" />}
          </IconButton>
        </div>
      </header>
      <div className={`reading-stage ${mode === "text" ? "text-stage" : ""}`}>
        {mode === "rsvp" ? (
          <div
            className="rsvp-stage"
            onClick={(e) => {
              if (
                e.target instanceof HTMLElement &&
                !e.target.closest("button")
              ) {
                session.toggle();
                reveal();
              }
            }}
          >
            {speedHUD !== undefined && (
              <div className="speed-hud" role="status">
                {speedHUD}
                <span>WPM</span>
              </div>
            )}
            <div
              className="focus-word-area"
              aria-label={`${state.playing ? "Reading" : "Current word"}: ${word}`}
            >
              <div className="focus-guide top" />
              <div
                className="rsvp-word"
                style={
                  {
                    "--word-size": `${state.preferences.fontSize}px`,
                    "--fit-chars": Math.max(
                      9,
                      1.3 *
                        Math.max(
                          Array.from(prefix).length,
                          Array.from(after).length,
                        ) +
                        1,
                    ),
                  } as CSSProperties
                }
                aria-hidden="true"
              >
                <span className="word-prefix">{prefix}</span>
                <span className="word-pivot">{center}</span>
                <span className="word-suffix">{after}</span>
              </div>
              <div className="focus-guide bottom" />
            </div>
            <div
              className={`context-line ${showContext ? "" : "hidden"}`}
              aria-hidden="true"
            >
              <span>{contextBefore}</span>
              <strong>{word}</strong>
              <span>{contextAfter}</span>
            </div>
            {session.atEnd && !state.playing && (
              <div className="reading-complete">
                <Check size={17} />
                <span>Document complete</span>
                <button
                  type="button"
                  className="text-button"
                  onClick={() => session.seek(0, 0)}
                >
                  <RotateCcw size={14} />
                  Read again
                </button>
              </div>
            )}
          </div>
        ) : (
          <FullText
            text={current?.text ?? ""}
            tokens={tokens}
            index={session.displayIndex}
            chunk={state.preferences.chunkSize}
            playing={state.playing}
            title={current?.title ?? ""}
            onSeek={(index) => session.seek(state.sectionIndex, index)}
          />
        )}
      </div>
      <div
        className={`controls-area ${chrome ? "" : "chrome-hidden"}`}
        onFocusCapture={reveal}
        onMouseEnter={() => {
          clearTimeout(hideTimer.current);
          setChrome(true);
        }}
        onMouseLeave={reveal}
      >
        <div className="reader-controls" ref={controlsRef}>
          <div className="playback-buttons">
            <IconButton
              label="Previous words"
              onClick={() => session.step(false)}
              disabled={state.sectionIndex === 0 && state.wordIndex === 0}
            >
              <ChevronLeft size={22} />
            </IconButton>
            <button
              type="button"
              className="play-button"
              aria-label={
                state.playing
                  ? "Pause reading"
                  : session.atEnd
                    ? "Read again"
                    : "Start reading"
              }
              title={
                state.playing
                  ? "Pause reading (Space)"
                  : "Start reading (Space)"
              }
              onClick={(e) => {
                if (e.detail > 0) e.currentTarget.blur();
                session.toggle();
                reveal();
              }}
            >
              {state.playing ? (
                <Pause size={21} fill="currentColor" />
              ) : (
                <Play size={21} fill="currentColor" />
              )}
            </button>
            <IconButton
              label="Next words"
              onClick={() => session.step(true)}
              disabled={session.atEnd}
            >
              <ChevronRight size={22} />
            </IconButton>
          </div>
          <span className="control-divider" />
          <div className="speed-control">
            <IconButton
              label="Decrease reading speed"
              disabled={state.preferences.wordsPerMinute <= 100}
              onClick={() => changeSpeed(-25)}
            >
              <Minus size={14} />
            </IconButton>
            <label className="speed-value">
              <input
                aria-label="Reading speed"
                type="number"
                min="100"
                max="900"
                step="25"
                value={state.preferences.wordsPerMinute}
                onChange={(e) => {
                  if (e.target.value)
                    session.setPreferences({
                      wordsPerMinute: Number(e.target.value),
                    });
                }}
              />
              <span>WPM</span>
            </label>
            <IconButton
              label="Increase reading speed"
              disabled={state.preferences.wordsPerMinute >= 900}
              onClick={() => changeSpeed(25)}
            >
              <Plus size={14} />
            </IconButton>
          </div>
          <span className="control-divider progress-divider" />
          <div className="seek-control">
            <input
              aria-label="Section progress"
              type="range"
              min="0"
              max={Math.max(0, tokens.length - 1)}
              value={session.displayIndex}
              disabled={tokens.length < 2}
              style={
                {
                  "--range-progress": `${tokens.length > 1 ? (session.displayIndex / (tokens.length - 1)) * 100 : 0}%`,
                } as CSSProperties
              }
              onChange={(e) =>
                session.seek(state.sectionIndex, Number(e.target.value))
              }
            />
            <span>
              {Math.min(state.wordIndex + 1, tokens.length).toLocaleString(
                "en",
              )}{" "}
              / {tokens.length.toLocaleString("en")}
            </span>
          </div>
          <IconButton
            label="Reading options"
            onClick={() => openPanel("options")}
          >
            <SlidersHorizontal size={20} />
          </IconButton>
          {document.fullscreenEnabled && (
            <IconButton
              label={fullscreen ? "Exit fullscreen" : "Enter fullscreen"}
              className="fullscreen-button"
              onClick={fullscreenToggle}
            >
              {fullscreen ? <Minimize size={19} /> : <Maximize size={19} />}
            </IconButton>
          )}
        </div>
        <p
          className="remaining-time"
          title="Estimates use word count and selected WPM, excluding optional pauses."
        >
          <span>{formatTime(remaining)} in section</span>
          <span>{formatTime(remainingBook)} in document</span>
        </p>
      </div>
      {panel === "options" && (
        <Modal
          title="Reading options"
          className="options-modal"
          onClose={() => setPanel(undefined)}
          footer={
            <button
              type="button"
              className="button"
              onClick={() => setPanel(undefined)}
            >
              Done
            </button>
          }
        >
          <Options
            value={state.preferences}
            onChange={session.setPreferences}
            theme={theme}
            onTheme={onTheme}
          />
        </Modal>
      )}
      {panel === "chapters" && (
        <Modal
          title="Chapters"
          className="chapters-modal"
          onClose={() => setPanel(undefined)}
        >
          <div className="chapter-list">
            {book.sections.map((s, i) => (
              <button
                type="button"
                className={i === state.sectionIndex ? "current" : ""}
                key={s.id}
                onClick={() => {
                  session.seek(i, 0);
                  setPanel(undefined);
                }}
              >
                <span className="chapter-index">{i + 1}</span>
                <span>
                  <strong>{s.title}</strong>
                  <small>{s.wordCount.toLocaleString("en")} words</small>
                </span>
                {i === state.sectionIndex ? (
                  <BookOpen size={18} />
                ) : (
                  <ChevronRight size={17} />
                )}
              </button>
            ))}
          </div>
        </Modal>
      )}
      {panel === "search" && (
        <DocumentSearch
          book={book}
          onClose={() => setPanel(undefined)}
          onJump={(section, word) => {
            session.seek(section, word);
            setPanel(undefined);
          }}
        />
      )}
      {panel === "notes" && (
        <Notes
          book={book}
          progress={state}
          onClose={() => setPanel(undefined)}
          onChange={onNotes}
          onJump={(section, word) => {
            session.seek(section, word);
            setPanel(undefined);
          }}
        />
      )}
    </main>
  );
}

const FullText = memo(function FullText({
  text,
  tokens,
  index,
  chunk,
  title,
  onSeek,
  playing,
}: {
  text: string;
  tokens: Token[];
  index: number;
  chunk: number;
  title: string;
  onSeek: (index: number) => void;
  playing: boolean;
}) {
  const content = useRef<HTMLDivElement>(null);
  const customHighlight =
    typeof CSS !== "undefined" &&
    "highlights" in CSS &&
    typeof Highlight !== "undefined";
  const nodes = useMemo(() => {
    if (customHighlight) return text;
    const result: React.ReactNode[] = [];
    let end = 0;
    tokens.forEach((token, i) => {
      if (token.start > end) result.push(text.slice(end, token.start));
      result.push(
        <span key={i} data-word={i}>
          {token.text}
        </span>,
      );
      end = token.end;
    });
    if (end < text.length) result.push(text.slice(end));
    return result;
  }, [text, tokens, customHighlight]);
  useEffect(() => {
    const root = content.current;
    if (!root) return;
    let word: DOMRect | undefined;
    if (
      customHighlight &&
      root.firstChild?.nodeType === Node.TEXT_NODE &&
      tokens[index]
    ) {
      const range = new Range();
      range.setStart(root.firstChild, tokens[index].start);
      range.setEnd(
        root.firstChild,
        tokens[Math.min(index + chunk - 1, tokens.length - 1)].end,
      );
      CSS.highlights.set("reader-current", new Highlight(range));
      word = range.getBoundingClientRect();
    } else {
      root
        .querySelectorAll("[data-current]")
        .forEach((el) => el.removeAttribute("data-current"));
      for (let i = index; i < index + chunk; i++)
        root
          .querySelector(`[data-word="${i}"]`)
          ?.setAttribute("data-current", "true");
      word = root
        .querySelector(`[data-word="${index}"]`)
        ?.getBoundingClientRect();
    }
    if (word) {
      const stage = root.closest(".text-stage")!;
      const bounds = stage.getBoundingClientRect();
      if (word.top < bounds.top + 75 || word.bottom > bounds.bottom - 150) {
        const reducedMotion = matchMedia(
          "(prefers-reduced-motion: reduce)",
        ).matches;
        stage.scrollTo({
          top: stage.scrollTop + word.top - bounds.top - bounds.height * 0.35,
          behavior: playing || reducedMotion ? "instant" : "smooth",
        });
      }
    }
  }, [index, chunk, playing, nodes, tokens, customHighlight]);
  useEffect(
    () => () => {
      if (customHighlight) CSS.highlights.delete("reader-current");
    },
    [customHighlight],
  );
  return (
    <article className="full-text">
      <h2>{title}</h2>
      <div
        className="full-text-body"
        ref={content}
        onClick={(e) => {
          if (window.getSelection()?.toString()) return;
          if (customHighlight) {
            const position = document.caretPositionFromPoint?.(
              e.clientX,
              e.clientY,
            );
            const fallback = !position
              ? document.caretRangeFromPoint?.(e.clientX, e.clientY)
              : undefined;
            const node = position?.offsetNode ?? fallback?.startContainer;
            const offset = position?.offset ?? fallback?.startOffset;
            if (node === content.current?.firstChild && offset !== undefined)
              onSeek(tokenIndexAtOffset(tokens, offset));
          } else {
            const target = (e.target as HTMLElement).closest<HTMLElement>(
              "[data-word]",
            );
            if (target) onSeek(Number(target.dataset.word));
          }
        }}
        tabIndex={0}
        aria-label="Document text. Click a word to continue reading from it."
      >
        {nodes}
      </div>
    </article>
  );
});

function DocumentSearch({
  book,
  onClose,
  onJump,
}: {
  book: Book;
  onClose: () => void;
  onJump: (section: number, word: number) => void;
}) {
  const [query, setQuery] = useState("");
  const [matches, setMatches] = useState<SearchMatch[]>([]);
  const [searching, setSearching] = useState(false);
  const worker = useRef<Worker>(undefined);
  const request = useRef(0);
  useEffect(() => {
    worker.current = new Worker(
      new URL("../core/search.worker.ts", import.meta.url),
      { type: "module" },
    );
    worker.current.onmessage = (e) => {
      if (e.data.id === request.current) {
        setMatches(e.data.matches);
        setSearching(false);
      }
    };
    return () => worker.current?.terminate();
  }, []);
  useEffect(() => {
    const id = ++request.current;
    if (!query.trim()) {
      setMatches([]);
      setSearching(false);
      return;
    }
    setSearching(true);
    const timer = setTimeout(
      () => worker.current?.postMessage({ id, sections: book.sections, query }),
      140,
    );
    return () => clearTimeout(timer);
  }, [query, book.sections]);
  return (
    <Modal title="Search document" onClose={onClose} className="search-modal">
      <div className="search-field">
        <Search size={18} />
        <input
          autoFocus
          type="search"
          aria-label="Search in document"
          placeholder="Find a word or phrase"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter" && matches[0])
              onJump(matches[0].sectionIndex, matches[0].wordIndex);
          }}
        />
        {query && (
          <IconButton
            label="Clear document search"
            onClick={() => setQuery("")}
          >
            <X size={16} />
          </IconButton>
        )}
      </div>
      <div className="search-summary" role="status">
        {searching
          ? "Searching..."
          : query.trim()
            ? `${matches.length === 500 ? "First 500" : matches.length} ${matches.length === 1 ? "match" : "matches"}`
            : "Search across all chapters"}
      </div>
      <div className="search-results">
        {matches.map((m, i) => (
          <button
            type="button"
            key={`${m.sectionIndex}-${m.wordIndex}-${i}`}
            onClick={() => onJump(m.sectionIndex, m.wordIndex)}
          >
            <small>{book.sections[m.sectionIndex].title}</small>
            <span>
              {m.before}
              <mark>{m.match}</mark>
              {m.after}
            </span>
          </button>
        ))}
        {query.trim() && !searching && !matches.length && (
          <p className="empty-message">
            No matches. Try another word or phrase.
          </p>
        )}
      </div>
    </Modal>
  );
}

function Notes({
  book,
  progress,
  onClose,
  onChange,
  onJump,
}: {
  book: Book;
  progress: Progress;
  onClose: () => void;
  onChange: (notes: Note[]) => void;
  onJump: (section: number, word: number) => void;
}) {
  const [text, setText] = useState("");
  const [editing, setEditing] = useState<string>();
  const save = () => {
    if (!text.trim()) return;
    if (editing)
      onChange(
        book.notes.map((n) =>
          n.id === editing ? { ...n, text: text.trim() } : n,
        ),
      );
    else
      onChange([
        ...book.notes,
        {
          id: crypto.randomUUID(),
          text: text.trim(),
          sectionIndex: progress.sectionIndex,
          wordIndex: progress.wordIndex,
          createdAt: Date.now(),
        },
      ]);
    setText("");
    setEditing(undefined);
  };
  return (
    <Modal
      title="Notes"
      onClose={onClose}
      className="notes-modal"
      footer={
        <button type="button" className="button" onClick={onClose}>
          Done
        </button>
      }
    >
      <label className="field-label" htmlFor="note-text">
        {editing ? "Edit note" : "Note at your current position"}
      </label>
      <textarea
        id="note-text"
        placeholder="Write a thought, save a passage..."
        value={text}
        onChange={(e) => setText(e.target.value)}
        autoFocus
      />
      <div className="note-compose-footer">
        <span className="fine-print">
          {book.sections[progress.sectionIndex]?.title}
        </span>
        {editing && (
          <button
            type="button"
            className="button"
            onClick={() => {
              setEditing(undefined);
              setText("");
            }}
          >
            Cancel edit
          </button>
        )}
        <button
          type="button"
          className="button primary"
          disabled={!text.trim()}
          onClick={save}
        >
          {editing ? "Save note" : "Add note"}
        </button>
      </div>
      <div className="notes-list">
        {[...book.notes]
          .sort((a, b) => b.createdAt - a.createdAt)
          .map((n) => (
            <div className="note" key={n.id}>
              <p>{n.text}</p>
              <div className="note-meta">
                <button
                  type="button"
                  className="text-button"
                  onClick={() => onJump(n.sectionIndex, n.wordIndex)}
                >
                  {book.sections[n.sectionIndex]?.title ?? "Section"}
                  <ChevronRight size={13} />
                </button>
                <span>
                  {new Date(n.createdAt).toLocaleDateString("en", {
                    month: "short",
                    day: "numeric",
                  })}
                </span>
              </div>
              <div className="note-actions">
                <button
                  type="button"
                  className="text-button"
                  onClick={() => {
                    setEditing(n.id);
                    setText(n.text);
                    document.getElementById("note-text")?.focus();
                  }}
                >
                  Edit
                </button>
                <button
                  type="button"
                  className="text-button danger-text"
                  onClick={() => {
                    onChange(book.notes.filter((v) => v.id !== n.id));
                    if (editing === n.id) {
                      setEditing(undefined);
                      setText("");
                    }
                  }}
                >
                  Delete
                </button>
              </div>
            </div>
          ))}
        {!book.notes.length && (
          <div className="notes-empty">
            <StickyNote size={25} strokeWidth={1.4} />
            <p>Your notes will appear here.</p>
            <span>Each note remembers your place in the document.</span>
          </div>
        )}
      </div>
    </Modal>
  );
}
