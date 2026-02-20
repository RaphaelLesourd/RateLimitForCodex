import SwiftUI

struct CodexProgressSectionView: View {
  let snapshot: RateLimitSnapshot

  var body: some View {
    let primaryWindowTitle = windowTitle(windowMinutes: snapshot.sessionPrimaryWindowMinutes, fallbackKey: "progress.primary_window_fallback")
    let secondaryWindowTitle = windowTitle(windowMinutes: snapshot.sessionSecondaryWindowMinutes, fallbackKey: "progress.secondary_window_fallback")

    VStack(alignment: .leading, spacing: 12) {
      progressRow(
        title: primaryWindowTitle,
        usedPercent: snapshot.sessionPrimaryUsedPercent,
        resetAt: snapshot.sessionPrimaryResetsAt
      )

      progressRow(
        title: secondaryWindowTitle,
        usedPercent: snapshot.sessionSecondaryUsedPercent,
        resetAt: snapshot.sessionSecondaryResetsAt
      )
    }
  }

  private func windowTitle(windowMinutes: Int?, fallbackKey: String.LocalizationValue) -> String {
    guard let windowMinutes else { return String(localized: fallbackKey) }
    if windowMinutes >= 10080 {
      return String(localized: "progress.window.weekly")
    }
    if windowMinutes % 60 == 0 {
      return localizedFormat("progress.window.hour_format", String(windowMinutes / 60))
    }
    return localizedFormat("progress.window.minute_format", String(windowMinutes))
  }

  @ViewBuilder
  private func progressRow(title: String, usedPercent: Double?, resetAt: Date?) -> some View {
    let displayUsed = displayedUsedPercent(fromUsedPercent: usedPercent)
    let usedFraction = max(0, min(1, displayUsed / 100.0))

    VStack(alignment: .leading, spacing: 6) {
      Text(localizedFormat("progress.row.used_format", title, String(Int(displayUsed.rounded()))))
        .font(.system(size: 14, weight: .semibold, design: .rounded))
        .foregroundStyle(.primary)

      ProgressView(value: usedFraction)
        .progressViewStyle(.linear)
        .tint(progressColor(usedPercent: displayUsed))

      HStack {
        Spacer()
        Text(resetText(resetAt))
          .font(.system(size: 12, weight: .medium, design: .rounded))
          .foregroundStyle(.secondary)
      }
    }
  }

  private func displayedUsedPercent(fromUsedPercent usedPercent: Double?) -> Double {
    guard let usedPercent else { return 0 }
    return max(0, min(100, usedPercent))
  }

  private func resetText(_ date: Date?) -> String {
    guard let date else { return String(localized: "progress.reset.none") }
    if Calendar.current.isDateInToday(date) {
      return localizedFormat("progress.reset.at_format", Self.resetTimeFormatter.string(from: date))
    }
    return localizedFormat("progress.reset.on_format", Self.resetDateFormatter.string(from: date))
  }

  private func progressColor(usedPercent: Double) -> Color {
    if usedPercent >= 80 {
      return .red
    }
    if usedPercent >= 50 {
      return .orange
    }
    return .green
  }

  private static let resetTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    return formatter
  }()

  private static let resetDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .none
    return formatter
  }()

  private func localizedFormat(_ key: String.LocalizationValue, _ arguments: CVarArg...) -> String {
    String(format: String(localized: key), locale: Locale.current, arguments: arguments)
  }
}
