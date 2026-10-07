import { useEffect, useState } from "react";
import { BarChart3 } from "lucide-react";
import { loadStats } from "../core/storage";
import { formatTime, localDate, type DailyStats } from "../core/types";
import { Modal } from "./primitives";

export function Statistics({ onClose }: { onClose: () => void }) {
  const [stats, setStats] = useState<DailyStats[]>([]);
  const [error, setError] = useState("");
  useEffect(() => {
    void loadStats()
      .then(setStats)
      .catch(() => setError("Reading statistics could not be loaded."));
  }, []);
  const days = Array.from({ length: 14 }, (_, i) => {
    const d = new Date();
    d.setDate(d.getDate() - 13 + i);
    const date = localDate(d.getTime());
    return stats.find((s) => s.date === date) ?? { date, words: 0, seconds: 0 };
  });
  const today = days.at(-1)!;
  const week = days
    .slice(-7)
    .reduce(
      (a, s) => ({ words: a.words + s.words, seconds: a.seconds + s.seconds }),
      { words: 0, seconds: 0 },
    );
  const total = stats.reduce(
    (a, s) => ({ words: a.words + s.words, seconds: a.seconds + s.seconds }),
    { words: 0, seconds: 0 },
  );
  const max = Math.max(100, ...days.map((s) => s.words));
  return (
    <Modal
      title="Reading statistics"
      onClose={onClose}
      className="statistics-modal"
      footer={
        <>
          <span className="fine-print">
            Includes punctuation and pacing pauses.
          </span>
          <button type="button" className="button" onClick={onClose}>
            Done
          </button>
        </>
      }
    >
      <div className="stats-grid">
        <div>
          <span>Today</span>
          <strong>{today.words.toLocaleString("en")}</strong>
          <small>words read</small>
        </div>
        <div>
          <span>Last 7 days</span>
          <strong>{week.words.toLocaleString("en")}</strong>
          <small>words read</small>
        </div>
        <div>
          <span>Average speed</span>
          <strong>
            {total.seconds > 0
              ? Math.round((total.words * 60) / total.seconds)
              : 0}
          </strong>
          <small>WPM</small>
        </div>
        <div>
          <span>Reading time</span>
          <strong>{formatTime(total.seconds)}</strong>
          <small>all time</small>
        </div>
      </div>
      <div className="chart-heading">
        <h3>Last 14 days</h3>
        <span>{total.words.toLocaleString("en")} words read in total</span>
      </div>
      <div
        className="reading-chart"
        role="img"
        aria-label={`Words read in the last 14 days: ${days.map((s) => `${s.date}: ${s.words}`).join(", ")}`}
      >
        <div className="chart-scale">
          <span>{max.toLocaleString("en")}</span>
          <span>{Math.round(max / 2).toLocaleString("en")}</span>
          <span>0</span>
        </div>
        <div className="chart-plot">
          <div className="chart-grid-lines">
            <i />
            <i />
            <i />
          </div>
          <div className="chart-bars">
            {days.map((s, i) => (
              <div className="chart-column" key={s.date}>
                <div
                  className={`chart-bar ${i === 13 ? "today" : ""}`}
                  style={{ height: `${(s.words / max) * 100}%` }}
                  title={`${new Date(`${s.date}T12:00:00`).toLocaleDateString("en", { month: "short", day: "numeric" })}: ${s.words.toLocaleString("en")} words`}
                />
                <span>
                  {[0, 3, 6, 9, 13].includes(i)
                    ? new Date(`${s.date}T12:00:00`).toLocaleDateString("en", {
                        month: "short",
                        day: "numeric",
                      })
                    : ""}
                </span>
              </div>
            ))}
          </div>
        </div>
      </div>
      {!total.words && (
        <p className="stats-empty">
          <BarChart3 size={17} />
          Start reading to see your progress here.
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
