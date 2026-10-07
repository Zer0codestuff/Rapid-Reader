import { useRef, useState } from "react";
import { Upload, Link, Clipboard, FileText, ArrowUpRight } from "lucide-react";
import { Modal } from "./primitives";
import { supportedFiles } from "../import";

export type ImportTab = "files" | "article" | "text";
export function ImportDialog({
  onClose,
  onFiles,
  onArticle,
  onText,
  busy,
  status,
  error,
  initialTab = "files",
}: {
  onClose: () => void;
  onFiles: (files: File[]) => void;
  onArticle: (url: string) => void;
  onText: (text: string, title?: string) => void;
  busy: boolean;
  status: string;
  error?: string;
  initialTab?: ImportTab;
}) {
  const [tab, setTab] = useState(initialTab);
  const [url, setURL] = useState("");
  const [text, setText] = useState("");
  const [title, setTitle] = useState("");
  const [dragging, setDragging] = useState(false);
  const [clipboardError, setClipboardError] = useState("");
  const input = useRef<HTMLInputElement>(null);
  const tabs = [
    { value: "files", label: "Files", icon: Upload },
    { value: "article", label: "Article", icon: Link },
    { value: "text", label: "Paste text", icon: Clipboard },
  ] as const;
  async function clipboard() {
    try {
      setText(await navigator.clipboard.readText());
      setClipboardError("");
    } catch {
      setClipboardError(
        "Paste your text below with your keyboard or the browser menu.",
      );
    }
  }
  return (
    <Modal
      title="Add to your library"
      onClose={onClose}
      className="import-modal"
      footer={
        <>
          <span className="fine-print">
            Files and pasted text stay on this device.
          </span>
          <button type="button" className="button" onClick={onClose}>
            {busy ? "Close" : "Cancel"}
          </button>
          {tab !== "files" && (
            <button
              type="button"
              className="button primary"
              disabled={busy || (tab === "text" ? !text.trim() : !url.trim())}
              onClick={() =>
                tab === "text" ? onText(text, title) : onArticle(url)
              }
            >
              {busy ? "Importing..." : "Add to library"}
            </button>
          )}
        </>
      }
    >
      <div className="import-tabs" role="tablist" aria-label="Import source">
        {tabs.map((t) => (
          <button
            type="button"
            role="tab"
            aria-selected={tab === t.value}
            key={t.value}
            disabled={busy}
            onClick={() => setTab(t.value)}
          >
            <t.icon size={17} />
            {t.label}
          </button>
        ))}
      </div>
      <div
        className="import-panel"
        role="tabpanel"
        aria-label={tabs.find((t) => t.value === tab)!.label}
      >
        {tab === "files" && (
          <>
            <input
              ref={input}
              type="file"
              multiple
              accept={supportedFiles}
              hidden
              onChange={(e) => {
                if (e.target.files?.length) onFiles([...e.target.files]);
                e.target.value = "";
              }}
            />
            <button
              type="button"
              className={`drop-zone ${dragging ? "dragging" : ""}`}
              disabled={busy}
              onClick={() => input.current?.click()}
              onDragOver={(e) => {
                e.preventDefault();
                setDragging(true);
              }}
              onDragLeave={() => setDragging(false)}
              onDrop={(e) => {
                e.preventDefault();
                e.stopPropagation();
                setDragging(false);
                if (!busy && e.dataTransfer.files.length)
                  onFiles([...e.dataTransfer.files]);
              }}
            >
              <span className="drop-icon">
                <Upload size={26} strokeWidth={1.4} />
              </span>
              <strong>
                {busy ? "Adding your documents" : "Drop your documents here"}
              </strong>
              <span>or choose files</span>
              <span className="file-types">
                EPUB, PDF, DOCX, RTF, HTML, Markdown, TXT
              </span>
            </button>
            <p className="fine-print import-file-note">
              <FileText size={14} />
              Up to 100 MB per file. PDFs need selectable text.
            </p>
          </>
        )}
        {tab === "article" && (
          <form
            onSubmit={(e) => {
              e.preventDefault();
              if (url.trim() && !busy) onArticle(url);
            }}
          >
            <label className="field-label" htmlFor="article-url">
              Article URL
            </label>
            <div className="url-field">
              <Link size={17} />
              <input
                id="article-url"
                type="text"
                inputMode="url"
                autoComplete="url"
                placeholder="https://example.com/article"
                value={url}
                autoFocus
                onChange={(e) => setURL(e.target.value)}
                disabled={busy}
              />
            </div>
            <p className="fine-print">
              The article is fetched once, then saved in your browser. Pages
              behind a login or paywall may need to be pasted as text.
            </p>
            <button type="submit" hidden>
              Import article
            </button>
            <span className="article-hint">
              <ArrowUpRight size={15} />
              Only the article text is kept.
            </span>
          </form>
        )}
        {tab === "text" && (
          <>
            <div className="paste-title">
              <label className="field-label" htmlFor="paste-title">
                Title <span>Optional</span>
              </label>
              <button
                type="button"
                className="text-button"
                disabled={busy}
                onClick={clipboard}
              >
                <Clipboard size={14} />
                Read clipboard
              </button>
            </div>
            <input
              id="paste-title"
              className="text-field"
              placeholder="Uses the first line if left blank"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              disabled={busy}
            />
            <label className="field-label" htmlFor="paste-text">
              Text
            </label>
            <textarea
              id="paste-text"
              placeholder="Paste the text you want to read..."
              value={text}
              onChange={(e) => setText(e.target.value)}
              disabled={busy}
              autoFocus
            />
            <span className="fine-print">
              {clipboardError ||
                `${text.trim() ? text.trim().split(/\s+/).length.toLocaleString("en") : 0} words`}
            </span>
          </>
        )}
      </div>
      {busy && (
        <p className="import-status" role="status">
          {status}
        </p>
      )}
      {error && (
        <p className="inline-error" role="alert">
          {error}
        </p>
      )}
    </Modal>
  );
}
