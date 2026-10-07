import { useCallback, useEffect, useRef, useState } from "react";
import {
  PanelLeft,
  Plus,
  Upload,
  Link,
  Clipboard,
  X,
  AlertCircle,
  Check,
  BookOpen,
  WifiOff,
} from "lucide-react";
import { Sidebar } from "./components/Sidebar";
import { Reader } from "./components/Reader";
import { ImportDialog, type ImportTab } from "./components/ImportDialog";
import { Statistics } from "./components/Statistics";
import { Settings } from "./components/Settings";
import { IconButton, Modal } from "./components/primitives";
import * as storage from "./core/storage";
import {
  defaultSettings,
  metadata,
  type Book,
  type BookMetadata,
  type Preferences,
  type Progress,
  type Settings as SettingsValue,
  type ImportedDocument,
} from "./core/types";
import { importArticle, importFile, importText } from "./import";

export default function App() {
  const [books, setBooks] = useState<BookMetadata[]>([]);
  const [book, setBook] = useState<Book>();
  const [settings, setSettings] = useState<SettingsValue>(defaultSettings);
  const [ready, setReady] = useState(false);
  const [fatal, setFatal] = useState("");
  const [sidebar, setSidebar] = useState(true);
  const [mobileOpen, setMobileOpen] = useState(false);
  const [dialog, setDialog] = useState<"import" | "stats" | "settings">();
  const [importTab, setImportTab] = useState<ImportTab>("files");
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState("");
  const [importError, setImportError] = useState("");
  const [deleting, setDeleting] = useState<BookMetadata>();
  const [dragging, setDragging] = useState(false);
  const [toast, setToast] = useState<{ message: string; error?: boolean }>();
  const [online, setOnline] = useState(navigator.onLine);
  const [update, setUpdate] = useState<ServiceWorker>();
  const bookRef = useRef(book);
  const settingsRef = useRef(settings);
  const busyRef = useRef(false);
  const saveQueue = useRef<Promise<unknown>>(Promise.resolve());
  const toastTimer = useRef<ReturnType<typeof setTimeout>>(undefined);
  const fileInput = useRef<HTMLInputElement>(null);
  const importController = useRef<AbortController>(undefined);
  const openRequest = useRef(0);
  const dragDepth = useRef(0);
  settingsRef.current = settings;
  const notify = useCallback((message: string, error = false) => {
    clearTimeout(toastTimer.current);
    setToast({ message, error });
    if (!error)
      toastTimer.current = setTimeout(() => setToast(undefined), 4500);
  }, []);
  const reportError = useCallback(
    (e: unknown) =>
      notify(
        e instanceof Error ? e.message : "This action could not be completed.",
        true,
      ),
    [notify],
  );
  const reloadBooks = useCallback(
    async () => setBooks(await storage.loadLibrary()),
    [],
  );
  const updateSettings = useCallback(
    (value: SettingsValue) => {
      settingsRef.current = value;
      setSettings(value);
      void storage.saveSettings(value).catch(reportError);
    },
    [reportError],
  );
  const updateMetadata = useCallback(
    (value: Book) =>
      setBooks((old) =>
        old
          .map((b) => (b.id === value.id ? metadata(value) : b))
          .sort(
            (a, b) =>
              (b.lastReadAt ?? b.importedAt) - (a.lastReadAt ?? a.importedAt),
          ),
      ),
    [],
  );
  const persistBook = useCallback(
    (value: Book, render = false) => {
      if (bookRef.current?.id === value.id) {
        bookRef.current = value;
        if (render) setBook(value);
      }
      updateMetadata(value);
      saveQueue.current = saveQueue.current
        .catch(() => {})
        .then(() => storage.saveBook(value))
        .catch(reportError);
    },
    [updateMetadata, reportError],
  );
  const progress = useCallback(
    (id: string, p: Progress, preferences: Preferences) => {
      const active = bookRef.current;
      if (active?.id === id)
        persistBook({
          ...active,
          progress: p,
          preferences,
          lastReadAt: Date.now(),
        });
    },
    [persistBook],
  );
  const segment = useCallback(
    (words: number, seconds: number, startedAt: number) => {
      saveQueue.current = saveQueue.current
        .catch(() => {})
        .then(() => storage.recordStats(words, seconds, startedAt))
        .catch(reportError);
    },
    [reportError],
  );
  const openBook = useCallback(
    async (id: string) => {
      const request = ++openRequest.current;
      try {
        // Pause the outgoing reader before loading another document.
        window.dispatchEvent(new Event("rapid-reader:pause"));
        await saveQueue.current;
        const value = await storage.loadBook(id);
        if (request !== openRequest.current) return;
        value.lastReadAt = Date.now();
        bookRef.current = value;
        setBook(value);
        persistBook(value);
        updateSettings({ ...settingsRef.current, selectedID: id });
        setMobileOpen(false);
      } catch (e) {
        reportError(e);
      }
    },
    [persistBook, updateSettings, reportError],
  );
  useEffect(() => {
    let alive = true;
    void Promise.all([storage.loadLibrary(), storage.loadSettings()])
      .then(async ([library, prefs]) => {
        if (!alive) return;
        setBooks(library);
        setSettings(prefs);
        settingsRef.current = prefs;
        const id = library.some((b) => b.id === prefs.selectedID)
          ? prefs.selectedID
          : library[0]?.id;
        if (id) {
          const value = await storage.loadBook(id);
          if (alive) {
            bookRef.current = value;
            setBook(value);
          }
        }
        if (alive) setReady(true);
      })
      .catch((e) => {
        if (alive) {
          setFatal(e.message);
          setReady(true);
        }
      });
    return () => {
      alive = false;
      clearTimeout(toastTimer.current);
    };
  }, []);
  useEffect(() => {
    document.documentElement.dataset.theme = settings.theme;
  }, [settings.theme]);
  useEffect(() => {
    const network = () => setOnline(navigator.onLine);
    window.addEventListener("online", network);
    window.addEventListener("offline", network);
    if (import.meta.env.PROD && "serviceWorker" in navigator)
      void navigator.serviceWorker
        .register("/sw.js")
        .then((registration) => {
          if (registration.waiting) setUpdate(registration.waiting);
          registration.addEventListener("updatefound", () => {
            const worker = registration.installing;
            worker?.addEventListener("statechange", () => {
              if (
                worker.state === "installed" &&
                navigator.serviceWorker.controller
              )
                setUpdate(worker);
            });
          });
        })
        .catch(() => {
          /* Online reading works when service workers are unavailable. */
        });
    return () => {
      window.removeEventListener("online", network);
      window.removeEventListener("offline", network);
    };
  }, []);
  const showImport = useCallback((tab: ImportTab = "files") => {
    window.dispatchEvent(new Event("rapid-reader:pause"));
    setImportTab(tab);
    setImportError("");
    setDialog("import");
  }, []);
  const beginImport = () => {
    if (busyRef.current || fatal) return false;
    busyRef.current = true;
    setBusy(true);
    setImportError("");
    return true;
  };
  const finishImport = () => {
    busyRef.current = false;
    setBusy(false);
    setStatus("");
  };
  const addDocument = async (doc: ImportedDocument) => {
    const result = await storage.importDocument(doc, settingsRef.current);
    await reloadBooks();
    await openBook(result.book.id);
    return result.duplicate;
  };
  const files = async (values: File[]) => {
    if (!beginImport()) return;
    window.dispatchEvent(new Event("rapid-reader:pause"));
    let imported = 0,
      duplicates = 0;
    const errors: string[] = [];
    for (const file of values) {
      try {
        const doc = await importFile(file, setStatus);
        const duplicate = await addDocument(doc);
        imported++;
        if (duplicate) duplicates++;
      } catch (e) {
        errors.push(`${file.name}: ${(e as Error).message}`);
      }
    }
    finishImport();
    if (errors.length) {
      setImportError(errors.join("\n"));
      setDialog("import");
      if (imported)
        notify(
          `${imported} ${imported === 1 ? "document added" : "documents added"}. ${errors.length} could not be imported.`,
          true,
        );
    } else {
      setDialog(undefined);
      notify(
        duplicates === imported
          ? "Already in your library. Your progress was kept."
          : `${imported} ${imported === 1 ? "document added" : "documents added"} to your library.`,
      );
    }
  };
  const text = async (value: string, title?: string) => {
    if (!beginImport()) return;
    try {
      const duplicate = await addDocument(importText(value, title));
      setDialog(undefined);
      notify(
        duplicate
          ? "Already in your library. Your progress was kept."
          : "Text added to your library.",
      );
    } catch (e) {
      setImportError((e as Error).message);
    } finally {
      finishImport();
    }
  };
  const article = async (url: string) => {
    if (!beginImport()) return;
    importController.current = new AbortController();
    setStatus("Retrieving article text...");
    try {
      const duplicate = await addDocument(
        await importArticle(url.trim(), importController.current.signal),
      );
      setDialog(undefined);
      notify(
        duplicate
          ? "Already in your library. Your progress was kept."
          : "Article added to your library.",
      );
    } catch (e) {
      if ((e as Error).name !== "AbortError")
        setImportError((e as Error).message);
    } finally {
      finishImport();
    }
  };
  const favorite = async (id: string) => {
    try {
      const value =
        bookRef.current?.id === id
          ? bookRef.current
          : await storage.loadBook(id);
      persistBook({ ...value, isFavorite: !value.isFavorite }, true);
    } catch (e) {
      reportError(e);
    }
  };
  const deleteSelected = async () => {
    if (!deleting) return;
    try {
      if (bookRef.current?.id === deleting.id) {
        window.dispatchEvent(new Event("rapid-reader:pause"));
        await saveQueue.current;
        ++openRequest.current;
        bookRef.current = undefined;
        setBook(undefined);
      }
      await storage.deleteBook(deleting.id);
      const library = await storage.loadLibrary();
      setBooks(library);
      if (settingsRef.current.selectedID === deleting.id) {
        updateSettings({ ...settingsRef.current, selectedID: undefined });
        if (library[0]) await openBook(library[0].id);
      }
      setDeleting(undefined);
      notify("Document deleted.");
    } catch (e) {
      reportError(e);
    }
  };
  const restore = async (file: File) => {
    try {
      if (file.size > 250 * 1024 * 1024)
        throw new Error("Choose a backup smaller than 250 MB.");
      const n = await storage.restoreLibrary(JSON.parse(await file.text()));
      const restoredSettings = await storage.loadSettings();
      updateSettings(restoredSettings);
      await reloadBooks();
      if (!bookRef.current) {
        const library = await storage.loadLibrary();
        if (library[0]) await openBook(library[0].id);
      }
      notify(
        `${n} ${n === 1 ? "document restored" : "documents restored"}. Existing progress was kept.`,
      );
    } catch (e) {
      reportError(e);
      throw e;
    }
  };
  useEffect(() => {
    const key = (e: KeyboardEvent) => {
      if (!(e.metaKey || e.ctrlKey) || document.querySelector("dialog[open]"))
        return;
      if (e.key.toLowerCase() === "o") {
        e.preventDefault();
        fileInput.current?.click();
      }
      if (e.shiftKey && e.key.toLowerCase() === "v") {
        e.preventDefault();
        showImport("text");
      }
    };
    window.addEventListener("keydown", key);
    return () => window.removeEventListener("keydown", key);
  }, [showImport]);
  const showLibrary = () => {
    if (window.innerWidth <= 800) setMobileOpen(!mobileOpen);
    else setSidebar(!sidebar);
  };
  const closeImport = () => {
    importController.current?.abort();
    setDialog(undefined);
  };
  return (
    <div
      className={`app ${sidebar ? "" : "sidebar-hidden"}`}
      onDragEnter={(e) => {
        if (e.dataTransfer.types.includes("Files")) {
          e.preventDefault();
          dragDepth.current++;
          setDragging(true);
        }
      }}
      onDragOver={(e) => {
        if (
          e.dataTransfer.types.includes("Files") ||
          e.dataTransfer.types.includes("text/uri-list")
        )
          e.preventDefault();
      }}
      onDragLeave={(e) => {
        if (e.dataTransfer.types.includes("Files")) {
          dragDepth.current--;
          if (dragDepth.current <= 0) setDragging(false);
        }
      }}
      onDrop={(e) => {
        e.preventDefault();
        dragDepth.current = 0;
        setDragging(false);
        if (e.dataTransfer.files.length && !busyRef.current) {
          setImportTab("files");
          setDialog("import");
          void files([...e.dataTransfer.files]);
        } else {
          const url = e.dataTransfer
            .getData("text/uri-list")
            .split("\n")
            .find((l) => l && !l.startsWith("#"));
          if (url && /^https?:\/\//i.test(url)) {
            showImport("article");
            void article(url);
          }
        }
      }}
    >
      <input
        ref={fileInput}
        type="file"
        accept=".epub,.pdf,.docx,.rtf,.html,.htm,.xhtml,.md,.markdown,.txt,.text"
        multiple
        hidden
        onChange={(e) => {
          if (e.target.files?.length) {
            setImportTab("files");
            setDialog("import");
            void files([...e.target.files]);
          }
          e.target.value = "";
        }}
      />
      {mobileOpen && (
        <button
          type="button"
          className="sidebar-scrim"
          aria-label="Close library"
          onClick={() => setMobileOpen(false)}
        />
      )}
      <Sidebar
        books={books}
        selectedID={book?.id}
        onSelect={(id) => void openBook(id)}
        onImport={() => showImport()}
        onStats={async () => {
          window.dispatchEvent(new Event("rapid-reader:pause"));
          await saveQueue.current;
          setDialog("stats");
        }}
        onSettings={() => {
          window.dispatchEvent(new Event("rapid-reader:pause"));
          setDialog("settings");
        }}
        onFavorite={(id) => void favorite(id)}
        onDelete={(id) => {
          window.dispatchEvent(new Event("rapid-reader:pause"));
          setDeleting(books.find((b) => b.id === id));
        }}
        onHide={showLibrary}
        mobileOpen={mobileOpen}
      />
      {book && !fatal ? (
        <Reader
          book={book}
          mode={settings.mode}
          onMode={(mode) => updateSettings({ ...settingsRef.current, mode })}
          theme={settings.theme}
          onTheme={(theme) => updateSettings({ ...settingsRef.current, theme })}
          onProgress={progress}
          onSegment={segment}
          onNotes={(notes) => {
            if (bookRef.current)
              persistBook({ ...bookRef.current, notes }, true);
          }}
          onFavorite={() => void favorite(book.id)}
          onLibrary={showLibrary}
        />
      ) : (
        <main className="empty-reader">
          <header className="reader-header">
            <IconButton label="Show library" onClick={showLibrary}>
              <PanelLeft size={20} />
            </IconButton>
            <span className="empty-header-title">Your reading space</span>
          </header>
          <div className="welcome">
            <img className="welcome-icon" src="/icon.png" alt="Rapid Reader" />
            <h1>
              {fatal
                ? "Your library needs attention"
                : ready
                  ? "A little more focus."
                  : "Opening your library"}
            </h1>
            <p>
              {fatal ||
                (ready
                  ? "Your books, documents and articles.\nOne word at a time, at your own pace."
                  : "Reading saved documents from this browser.")}
            </p>
            {ready && !fatal && (
              <>
                <button
                  type="button"
                  className="button primary welcome-add"
                  onClick={() => showImport()}
                >
                  <Plus size={18} />
                  Add a document
                </button>
                <div className="welcome-actions">
                  <button type="button" onClick={() => showImport("files")}>
                    <Upload size={15} />
                    Import file
                  </button>
                  <button type="button" onClick={() => showImport("article")}>
                    <Link size={15} />
                    Read an article
                  </button>
                  <button type="button" onClick={() => showImport("text")}>
                    <Clipboard size={15} />
                    Paste text
                  </button>
                </div>
                <span className="welcome-formats">
                  EPUB, PDF, Word, RTF, HTML, Markdown and text
                </span>
              </>
            )}
            {fatal && (
              <button
                type="button"
                className="button"
                onClick={() => setDialog("settings")}
              >
                Open backup settings
              </button>
            )}
          </div>
          <footer className="welcome-footer">
            <BookOpen size={15} />
            <span>Private library. No account needed.</span>
          </footer>
        </main>
      )}
      {!online && (
        <div className="network-status" role="status">
          <WifiOff size={14} />
          Offline. Your saved library is available.
        </div>
      )}
      {busy && dialog !== "import" && (
        <div className="background-import" role="status">
          {status || "Adding documents..."}
        </div>
      )}
      {toast && (
        <div
          className={`toast ${toast.error ? "error" : ""}`}
          role={toast.error ? "alert" : "status"}
        >
          {toast.error ? <AlertCircle size={18} /> : <Check size={18} />}
          <span>{toast.message}</span>
          <IconButton
            label="Dismiss notification"
            onClick={() => setToast(undefined)}
          >
            <X size={16} />
          </IconButton>
        </div>
      )}
      {update && (
        <div className="update-banner">
          <span>A new version is ready.</span>
          <button
            type="button"
            className="text-button"
            onClick={async () => {
              window.dispatchEvent(new Event("rapid-reader:pause"));
              await saveQueue.current;
              navigator.serviceWorker.addEventListener(
                "controllerchange",
                () => location.reload(),
                { once: true },
              );
              update.postMessage("ACTIVATE_UPDATE");
            }}
          >
            Update
          </button>
          <IconButton
            label="Dismiss update"
            onClick={() => setUpdate(undefined)}
          >
            <X size={14} />
          </IconButton>
        </div>
      )}
      {dragging && (
        <div className="global-drop">
          <Upload size={42} strokeWidth={1.3} />
          <h2>Drop to add to your library</h2>
        </div>
      )}
      {dialog === "import" && (
        <ImportDialog
          initialTab={importTab}
          onClose={closeImport}
          onFiles={(v) => void files(v)}
          onArticle={(v) => void article(v)}
          onText={(v, t) => void text(v, t)}
          busy={busy}
          status={status}
          error={importError}
        />
      )}
      {dialog === "stats" && (
        <Statistics onClose={() => setDialog(undefined)} />
      )}
      {dialog === "settings" && (
        <Settings
          value={settings}
          onChange={updateSettings}
          onClose={() => setDialog(undefined)}
          onRestore={restore}
          onError={reportError}
        />
      )}
      {deleting && (
        <Modal
          title="Delete document?"
          className="delete-modal"
          onClose={() => setDeleting(undefined)}
          footer={
            <>
              <button
                type="button"
                className="button"
                onClick={() => setDeleting(undefined)}
              >
                Cancel
              </button>
              <button
                type="button"
                className="button danger"
                onClick={() => void deleteSelected()}
              >
                Delete
              </button>
            </>
          }
        >
          <p>
            This removes <strong>{deleting.title}</strong>, its reading progress
            and notes from this library. The original file is kept.
          </p>
        </Modal>
      )}
    </div>
  );
}
