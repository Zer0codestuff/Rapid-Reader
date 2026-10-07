import { useState } from "react";
import {
  Search,
  Plus,
  BarChart3,
  Settings,
  Star,
  MoreHorizontal,
  BookOpen,
  FileText,
  Globe,
  Trash2,
  X,
  PanelLeftClose,
} from "lucide-react";
import { fold } from "../core/text";
import { fraction, formatLabels, type BookMetadata } from "../core/types";
import { IconButton } from "./primitives";

function relative(time?: number) {
  if (!time) return "";
  const minutes = Math.floor((Date.now() - time) / 60000);
  if (minutes < 1) return "Now";
  if (minutes < 60) return `${minutes} min ago`;
  if (minutes < 1440) return `${Math.floor(minutes / 60)} hr ago`;
  if (minutes < 2880) return "Yesterday";
  return new Date(time).toLocaleDateString("en", {
    month: "short",
    day: "numeric",
  });
}
export function Cover({
  book,
  size = "small",
}: {
  book: Pick<BookMetadata, "cover" | "format" | "title">;
  size?: "small" | "large";
}) {
  const Icon =
    book.format === "epub"
      ? BookOpen
      : book.format === "webArticle" || book.format === "html"
        ? Globe
        : FileText;
  return book.cover ? (
    <img
      className={`book-cover ${size}`}
      src={book.cover}
      alt={`${book.title} cover`}
      loading="lazy"
    />
  ) : (
    <span className={`book-cover fallback ${size}`} aria-hidden="true">
      <Icon size={size === "large" ? 30 : 20} strokeWidth={1.35} />
    </span>
  );
}
export function Sidebar({
  books,
  selectedID,
  onSelect,
  onImport,
  onStats,
  onSettings,
  onFavorite,
  onDelete,
  onHide,
  mobileOpen,
}: {
  books: BookMetadata[];
  selectedID?: string;
  onSelect: (id: string) => void;
  onImport: () => void;
  onStats: () => void;
  onSettings: () => void;
  onFavorite: (id: string) => void;
  onDelete: (id: string) => void;
  onHide: () => void;
  mobileOpen: boolean;
}) {
  const [query, setQuery] = useState("");
  const [favoritesOnly, setFavoritesOnly] = useState(false);
  const [menuID, setMenuID] = useState<string>();
  const filtered = books.filter(
    (b) =>
      (!favoritesOnly || b.isFavorite) &&
      fold(`${b.title} ${b.author ?? ""} ${b.sourceName}`).includes(
        fold(query),
      ),
  );
  const inProgress = filtered.filter(
    (b) => b.lastReadAt && fraction(b) > 0 && fraction(b) < 0.999,
  );
  const rest = filtered.filter((b) => !inProgress.some((p) => p.id === b.id));
  const rows = (items: BookMetadata[]) =>
    items.map((book) => (
      <div
        className={`library-item ${selectedID === book.id ? "selected" : ""}`}
        key={book.id}
        onContextMenu={(e) => {
          e.preventDefault();
          setMenuID(book.id);
        }}
      >
        <button
          type="button"
          className="book-button"
          aria-pressed={selectedID === book.id}
          onClick={() => {
            setMenuID(undefined);
            onSelect(book.id);
          }}
          onKeyDown={(e) => {
            if (e.key === "Delete" || e.key === "Backspace") {
              e.preventDefault();
              onDelete(book.id);
            }
          }}
        >
          <Cover book={book} />
          <span className="book-info">
            <span className="book-title">
              {book.title}
              {book.isFavorite && (
                <Star size={12} className="favorite-star" fill="currentColor" />
              )}
            </span>
            <span className="book-subtitle">
              {book.author || formatLabels[book.format]}
              {book.lastReadAt && (
                <span className="read-date">{relative(book.lastReadAt)}</span>
              )}
            </span>
            <span className="book-progress">
              <span style={{ width: `${fraction(book) * 100}%` }} />
            </span>
          </span>
        </button>
        <IconButton
          label={`More options for ${book.title}`}
          className="book-more"
          onClick={() => setMenuID(menuID === book.id ? undefined : book.id)}
        >
          <MoreHorizontal size={17} />
        </IconButton>
        {menuID === book.id && (
          <>
            <button
              className="menu-dismiss"
              aria-label="Dismiss document menu"
              onClick={() => setMenuID(undefined)}
            />
            <div className="book-menu" role="menu">
              <button
                role="menuitem"
                onClick={() => {
                  onFavorite(book.id);
                  setMenuID(undefined);
                }}
              >
                <Star size={16} />
                {book.isFavorite ? "Unfavorite" : "Favorite"}
              </button>
              <button
                role="menuitem"
                className="danger-text"
                onClick={() => {
                  onDelete(book.id);
                  setMenuID(undefined);
                }}
              >
                <Trash2 size={16} />
                Delete document
              </button>
            </div>
          </>
        )}
      </div>
    ));
  return (
    <aside
      className={`sidebar ${mobileOpen ? "mobile-open" : ""}`}
      aria-label="Library"
    >
      <div className="sidebar-top">
        <button
          type="button"
          className="brand"
          onClick={onHide}
          title="Hide library"
        >
          <img src="/icon.png" alt="" />
          <span>Rapid Reader</span>
        </button>
        <IconButton
          label="Hide library"
          className="sidebar-close"
          onClick={onHide}
        >
          <PanelLeftClose size={19} />
        </IconButton>
        <IconButton
          label="Add documents"
          className="add-button"
          onClick={onImport}
        >
          <Plus size={21} />
        </IconButton>
      </div>
      <div className="library-search">
        <Search size={16} />
        <input
          type="search"
          aria-label="Search library"
          placeholder="Search library"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />
        {query && (
          <IconButton label="Clear library search" onClick={() => setQuery("")}>
            <X size={14} />
          </IconButton>
        )}
      </div>
      <div className="library-filter">
        <span>
          {books.length} {books.length === 1 ? "document" : "documents"}
        </span>
        <button
          type="button"
          className={favoritesOnly ? "active" : ""}
          aria-pressed={favoritesOnly}
          onClick={() => setFavoritesOnly(!favoritesOnly)}
        >
          <Star size={13} fill={favoritesOnly ? "currentColor" : "none"} />
          Favorites
        </button>
      </div>
      <div className="library-list">
        {query || favoritesOnly ? (
          <section>
            <h2>{favoritesOnly ? "Favorites" : "Results"}</h2>
            {rows(filtered)}
          </section>
        ) : (
          <>
            {inProgress.length > 0 && (
              <section>
                <h2>Continue reading</h2>
                {rows(inProgress)}
              </section>
            )}
            {rest.length > 0 && (
              <section>
                <h2>Library</h2>
                {rows(rest)}
              </section>
            )}
          </>
        )}
        {filtered.length === 0 && (
          <div className="sidebar-empty">
            <BookOpen size={25} strokeWidth={1.3} />
            <p>
              {books.length
                ? favoritesOnly
                  ? "No favorites yet"
                  : "No matching documents"
                : "Your library starts here"}
            </p>
            {!books.length && (
              <button type="button" className="text-button" onClick={onImport}>
                Add a document
              </button>
            )}
          </div>
        )}
      </div>
      <footer className="sidebar-footer">
        <IconButton label="Reading statistics" onClick={onStats}>
          <BarChart3 size={20} />
        </IconButton>
        <span>Saved on this device</span>
        <IconButton label="Settings" onClick={onSettings}>
          <Settings size={19} />
        </IconButton>
      </footer>
    </aside>
  );
}
