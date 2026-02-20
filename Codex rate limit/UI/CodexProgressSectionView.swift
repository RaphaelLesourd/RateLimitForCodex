import SwiftUI

struct CodexProgressSectionView: View {
  let snapshot: RateLimitSnapshot

  var body: some View {
    let primaryWindowTitle = windowTitle(windowMinutes: snapshot.sessionPrimaryWindowMinutes, fallback: "Primary window")
    let secondaryWindowTitle = windowTitle(windowMinutes: snapshot.sessionSecondaryWindowMinutes, fallback: "Secondary window")

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

  private func windowTitle(windowMinutes: Int?, fallback: String) -> String {
    guard let windowMinutes else { return fallback }
    if windowMinutes >= 10080 {
      return "Weekly window"
    }
    if windowMinutes % 60 == 0 {
      return "\(windowMinutes / 60)-hour window"
    }
    return "\(windowMinutes)-minute window"
  }

  @ViewBuilder
  private func progressRow(title: String, usedPercent: Double?, resetAt: Date?) -> some View {
    let displayUsed = displayedUsedPercent(fromUsedPercent: usedPercent)
    let usedFraction = max(0, min(1, displayUsed / 100.0))

    VStack(alignment: .leading, spacing: 6) {
      Text("\(title): \(Int(displayUsed.rounded()))% used")
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
    guard let date else { return "Reset --" }
    if Calendar.current.isDateInToday(date) {
      return "Reset at \(Self.resetTimeFormatter.string(from: date))"
    }
    return "Reset on \(Self.resetDateFormatter.string(from: date))"
  }

  private func progressColor(usedPercent: Double) -> Color {
    if usedPercent >= 60 {
      return .red
    }
    if usedPercent >= 30 {
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
}
