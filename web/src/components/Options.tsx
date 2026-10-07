import { Sun, Moon, Monitor, BookOpen } from "lucide-react";
import type { Preferences, Theme } from "../core/types";
import { Stepper, Toggle } from "./primitives";

const themes = [
  { value: "system", label: "System", icon: Monitor },
  { value: "light", label: "Light", icon: Sun },
  { value: "dark", label: "Dark", icon: Moon },
  { value: "sepia", label: "Sepia", icon: BookOpen },
] as const;
export function ThemeSelector({
  theme,
  onChange,
}: {
  theme: Theme;
  onChange: (theme: Theme) => void;
}) {
  return (
    <div className="theme-selector" role="group" aria-label="Reader theme">
      {themes.map((t) => (
        <button
          key={t.value}
          type="button"
          aria-pressed={theme === t.value}
          onClick={() => onChange(t.value)}
        >
          <t.icon size={17} />
          <span>{t.label}</span>
        </button>
      ))}
    </div>
  );
}
export function Options({
  value: p,
  onChange,
  theme,
  onTheme,
  defaults = false,
}: {
  value: Preferences;
  onChange: (p: Partial<Preferences>) => void;
  theme: Theme;
  onTheme: (t: Theme) => void;
  defaults?: boolean;
}) {
  return (
    <div className="options">
      <section className="option-section">
        <h3>Appearance</h3>
        <ThemeSelector theme={theme} onChange={onTheme} />
        <label className="range-label">
          <span>
            Word size <output>{Math.round(p.fontSize)}</output>
          </span>
          <input
            aria-label="Word size"
            type="range"
            min="42"
            max="110"
            value={p.fontSize}
            onChange={(e) => onChange({ fontSize: Number(e.target.value) })}
          />
        </label>
        <div className="option-row">
          <span>Words at a time</span>
          <div
            className="segmented compact"
            role="group"
            aria-label="Words at a time"
          >
            {[1, 2, 3, 4].map((n) => (
              <button
                type="button"
                key={n}
                aria-pressed={p.chunkSize === n}
                onClick={() => onChange({ chunkSize: n })}
              >
                {n}
              </button>
            ))}
          </div>
        </div>
      </section>
      {defaults && (
        <section className="option-section">
          <label className="range-label">
            <span>
              Default speed <output>{p.wordsPerMinute} WPM</output>
            </span>
            <input
              aria-label="Default speed"
              type="range"
              min="100"
              max="900"
              step="25"
              value={p.wordsPerMinute}
              onChange={(e) =>
                onChange({ wordsPerMinute: Number(e.target.value) })
              }
            />
          </label>
        </section>
      )}
      <section className="option-section">
        <h3>Reading</h3>
        <Toggle
          label="Show surrounding words"
          checked={p.showContext}
          onChange={(showContext) => onChange({ showContext })}
        />
        <Toggle
          label="Hide them while playing"
          checked={p.focusMode}
          disabled={!p.showContext}
          onChange={(focusMode) => onChange({ focusMode })}
        />
        <Toggle
          label="Pause at punctuation"
          checked={p.pauseOnPunctuation}
          onChange={(pauseOnPunctuation) => onChange({ pauseOnPunctuation })}
        />
        <Toggle
          label="Slow down on long words"
          checked={p.pauseOnLongWords}
          onChange={(pauseOnLongWords) => onChange({ pauseOnLongWords })}
        />
      </section>
      <section className="option-section">
        <h3>Pacing</h3>
        <Stepper
          label="Warm-up"
          value={p.rampUpSeconds}
          min={0}
          max={10}
          suffix="s"
          onChange={(rampUpSeconds) => onChange({ rampUpSeconds })}
        />
        <Stepper
          label="Rewind on resume"
          value={p.resumeRewindWords}
          min={0}
          max={20}
          suffix="words"
          onChange={(resumeRewindWords) => onChange({ resumeRewindWords })}
        />
        <p className="fine-print">
          Warm-up starts at half speed. Long words stay on screen up to 60%
          longer.
        </p>
      </section>
    </div>
  );
}
