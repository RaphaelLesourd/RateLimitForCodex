import SwiftUI

struct AutoRefreshSectionView: View {
  @ObservedObject var viewModel: RateLimitViewModel

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Text(String(localized: "auto_refresh.title"))
          .font(.system(size: 14, weight: .bold, design: .rounded))
          .foregroundStyle(.primary)

        Spacer()

        Picker("", selection: $viewModel.refreshIntervalSeconds) {
          ForEach(RateLimitViewModel.supportedRefreshIntervals, id: \.self) { seconds in
            Text(localizedFormat("auto_refresh.interval_seconds_format", String(seconds))).tag(seconds)
          }
        }
        .pickerStyle(.menu)
        .labelsHidden()
      }

      Text(localizedFormat("auto_refresh.last_check_format", viewModel.statusText))
        .font(.caption)
        .foregroundStyle(.secondary)

      if !viewModel.isExperimentalMode, let tokenCost = viewModel.lastRefreshTokenCost {
        let burnText = viewModel.estimatedHourlyTokenBurnPercent
          .map {
            localizedFormat(
              "auto_refresh.burn_suffix_format",
              $0.formatted(.number.precision(.fractionLength(2))),
              viewModel.burnTrendSymbol
            )
          } ?? ""
        Text(localizedFormat("auto_refresh.cost_format", String(tokenCost), burnText))
          .font(.caption2)
          .foregroundStyle(.secondary)
      }

      HStack(spacing: 8) {
        Button(String(localized: "common.button.reload_now")) {
          viewModel.refresh()
        }
        .disabled(viewModel.isRefreshing)

        if viewModel.isRefreshing {
          ProgressView()
            .controlSize(.small)
        }

        Spacer()
      }
    }
  }

  private func localizedFormat(_ key: String.LocalizationValue, _ arguments: CVarArg...) -> String {
    String(format: String(localized: key), locale: Locale.current, arguments: arguments)
  }

}
