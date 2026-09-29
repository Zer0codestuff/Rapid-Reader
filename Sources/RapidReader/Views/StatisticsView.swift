import AppKit
import Charts
import RapidReaderCore
import SwiftUI

struct StatisticsView: View {
    @Environment(\.dismiss) private var dismiss
    let statistics: ReadingStatistics

    @State private var selectedDay: String?

    private var recent: [(date: Date, seconds: Double, words: Int)] {
        statistics.recentDays(14)
    }

    private func label(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.defaultDigits))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Reading Statistics").font(.title3.weight(.semibold))
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }

            HStack(spacing: 12) {
                StatTile(title: "Today", value: statistics.summary(lastDays: 1).seconds.readerDuration)
                StatTile(title: "Last 7 days", value: statistics.summary(lastDays: 7).seconds.readerDuration)
                StatTile(title: "Average speed", value: statistics.total.wordsPerMinute.map { String(localized: "\($0) WPM") } ?? "–")
                StatTile(title: "Words read", value: statistics.total.words.formatted())
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Minutes per day, last 14 days")
                    .font(.headline)
                Chart {
                    ForEach(recent, id: \.date) { day in
                        BarMark(
                            x: .value("Day", label(day.date)),
                            y: .value("Minutes", day.seconds / 60),
                            width: .fixed(16)
                        )
                        .foregroundStyle(Color.statisticsBar)
                        .cornerRadius(4)
                    }
                    if let selected = selectedEntry {
                        RuleMark(x: .value("Day", label(selected.date)))
                            .foregroundStyle(Color.secondary.opacity(0.25))
                            .annotation(position: .trailing, alignment: .top, spacing: 12, overflowResolution: .init(x: .fit(to: .plot), y: .fit(to: .plot))) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(selected.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                                        .font(.caption.weight(.semibold))
                                    Text(selected.seconds.readerDuration)
                                    Text("\(selected.words) words")
                                }
                                .font(.caption)
                                .padding(6)
                                .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                            }
                    }
                }
                .chartXSelection(value: $selectedDay)
                .chartXAxis {
                    // Label every other day, always including today.
                    AxisMarks(values: recent.indices.filter { ($0 - recent.count + 1) % 2 == 0 }.map { label(recent[$0].date) }) {
                        AxisValueLabel()
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                        AxisValueLabel()
                    }
                }
                .frame(height: 180)
            }

            Text("Measured while RSVP playback runs, including punctuation pauses. Stored only in this library.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 560)
    }

    private var selectedEntry: (date: Date, seconds: Double, words: Int)? {
        guard let selectedDay else { return nil }
        return recent.first { label($0.date) == selectedDay }
    }
}

private struct StatTile: View {
    let title: LocalizedStringKey
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }
}

private extension Color {
    /// Amber steps validated for at least 3:1 contrast on light and dark surfaces.
    static let statisticsBar = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.80, green: 0.48, blue: 0.09, alpha: 1)
            : NSColor(red: 0.76, green: 0.44, blue: 0.06, alpha: 1)
    })
}
