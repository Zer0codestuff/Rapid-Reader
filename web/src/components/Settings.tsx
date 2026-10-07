import { useEffect, useRef, useState } from "react";
import {
  Download,
  Upload,
  ShieldCheck,
  Keyboard,
  ExternalLink,
} from "lucide-react";
import {
  clampPreferences,
  localDate,
  type Settings as SettingsValue,
} from "../core/types";
import { exportLibrary } from "../core/storage";
import { Modal, downloadJSON } from "./primitives";
import { Options } from "./Options";

export function Settings({
  value,
  onChange,
  onClose,
  onRestore,
  onError,
}: {
  value: SettingsValue;
  onChange: (s: SettingsValue) => void;
  onClose: () => void;
  onRestore: (file: File) => Promise<void>;
  onError: (error: unknown) => void;
}) {
  const [tab, setTab] = useState<"reading" | "library" | "shortcuts">(
    "reading",
  );
  const [usage, setUsage] = useState<StorageEstimate>();
  const [persistent, setPersistent] = useState(false);
  const [busy, setBusy] = useState(false);
  const [storageMessage, setStorageMessage] = useState("");
  const input = useRef<HTMLInputElement>(null);
  useEffect(() => {
    void navigator.storage
      ?.estimate?.()
      .then(setUsage)
      .catch(() => {});
    void navigator.storage
      ?.persisted?.()
      .then(setPersistent)
      .catch(() => {});
  }, []);
  async function backup() {
    setBusy(true);
    try {
      downloadJSON(
        await exportLibrary(),
        `rapid-reader-backup-${localDate()}.json`,
      );
      setStorageMessage("Backup exported. Keep this file somewhere safe.");
    } catch (e) {
      onError(e);
      setStorageMessage((e as Error).message);
    } finally {
      setBusy(false);
    }
  }
  const shortcuts = [
    ["Space", "Play or pause"],
    ["← / →", "Previous or next words"],
    ["↑ / ↓", "Change speed by 25 WPM"],
    ["⌘ / Ctrl + F", "Search document"],
    ["⌘ / Ctrl + O", "Import files"],
    ["⌘ / Ctrl + Shift + V", "Paste text"],
    ["Escape", "Close a dialog"],
    ["Delete", "Delete a focused library document"],
  ] as const;
  return (
    <Modal
      title="Settings"
      onClose={onClose}
      className="settings-modal"
      footer={
        <button type="button" className="button" onClick={onClose}>
          Done
        </button>
      }
    >
      <div
        className="settings-tabs"
        role="tablist"
        aria-label="Settings section"
      >
        {(["reading", "library", "shortcuts"] as const).map((t) => (
          <button
            type="button"
            key={t}
            role="tab"
            aria-selected={tab === t}
            onClick={() => setTab(t)}
          >
            {t === "reading"
              ? "Reading defaults"
              : t === "library"
                ? "Your library"
                : "Shortcuts"}
          </button>
        ))}
      </div>
      {tab === "reading" && (
        <div role="tabpanel" aria-label="Reading defaults">
          <p className="settings-description">
            Defaults apply to new documents. Each document keeps its own reading
            options.
          </p>
          <Options
            value={value.defaults}
            onChange={(p) =>
              onChange({
                ...value,
                defaults: clampPreferences({ ...value.defaults, ...p }),
              })
            }
            theme={value.theme}
            onTheme={(theme) => onChange({ ...value, theme })}
            defaults
          />
        </div>
      )}
      {tab === "library" && (
        <div
          className="library-settings"
          role="tabpanel"
          aria-label="Your library"
        >
          <section>
            <h3>Stored on this device</h3>
            <p>
              Your documents, progress, notes and statistics live in this
              browser. Files and pasted text are never uploaded. Article URLs
              are sent to the server once to retrieve their text.
            </p>
            {usage && (
              <span className="storage-size">
                {((usage.usage ?? 0) / 1024 / 1024).toFixed(1)} MB used
                {usage.quota
                  ? ` of ${(usage.quota / 1024 / 1024 / 1024).toFixed(1)} GB available`
                  : ""}
              </span>
            )}
            <div className="storage-protection">
              <ShieldCheck size={19} />
              <span>
                {persistent
                  ? "Persistent storage is enabled"
                  : "Keep a backup before clearing browser data"}
              </span>
              {!persistent && navigator.storage?.persist && (
                <button
                  type="button"
                  className="button"
                  onClick={async () => {
                    const granted = await navigator.storage.persist();
                    setPersistent(granted);
                    setStorageMessage(
                      granted
                        ? "Your library is protected from automatic storage cleanup."
                        : "This browser did not grant persistent storage. Keep an exported backup.",
                    );
                  }}
                >
                  Protect library
                </button>
              )}
            </div>
            {storageMessage && (
              <p className="fine-print" role="status">
                {storageMessage}
              </p>
            )}
          </section>
          <section>
            <h3>Backups</h3>
            <p>
              Export your library to move it to another browser or device.
              Restoring adds documents and keeps existing progress.
            </p>
            <div className="backup-buttons">
              <button
                type="button"
                className="button"
                disabled={busy}
                onClick={backup}
              >
                <Download size={16} />
                Export backup
              </button>
              <button
                type="button"
                className="button"
                disabled={busy}
                onClick={() => input.current?.click()}
              >
                <Upload size={16} />
                Restore backup
              </button>
              <input
                ref={input}
                type="file"
                accept=".json,application/json"
                hidden
                onChange={async (e) => {
                  const file = e.target.files?.[0];
                  e.target.value = "";
                  if (!file) return;
                  setBusy(true);
                  try {
                    await onRestore(file);
                    setStorageMessage(
                      "Backup restored. Existing documents and progress were kept.",
                    );
                  } catch (e) {
                    setStorageMessage((e as Error).message);
                  } finally {
                    setBusy(false);
                  }
                }}
              />
            </div>
          </section>
          <section className="about-app">
            <img src="/icon.png" alt="" />
            <div>
              <strong>Rapid Reader</strong>
              <span>Free and open-source</span>
              <a
                href="https://github.com/Zer0codestuff/Rapid-Reader"
                target="_blank"
                rel="noreferrer"
              >
                Source code
                <ExternalLink size={13} />
              </a>
            </div>
          </section>
        </div>
      )}
      {tab === "shortcuts" && (
        <div role="tabpanel" aria-label="Shortcuts">
          <p className="settings-description">
            <Keyboard size={17} />
            Reader shortcuts are inactive while typing.
          </p>
          <dl className="shortcuts-list">
            {shortcuts.map(([key, label]) => (
              <div key={key}>
                <dt>{label}</dt>
                <dd>
                  <kbd>{key}</kbd>
                </dd>
              </div>
            ))}
          </dl>
          <p className="fine-print">
            Tap the reading stage to play or pause. In text mode, click a word
            to move to that position.
          </p>
        </div>
      )}
    </Modal>
  );
}
