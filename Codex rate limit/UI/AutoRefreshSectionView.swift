import SwiftUI

struct AutoRefreshSectionView: View {
  @ObservedObject var viewModel: RateLimitViewModel

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Text("Auto Refresh")
          .font(.system(size: 14, weight: .bold, design: .rounded))
          .foregroundStyle(.primary)

        Spacer()

        Picker("", selection: $viewModel.refreshIntervalSeconds) {
          ForEach(RateLimitViewModel.supportedRefreshIntervals, id: \.self) { seconds in
            Text("\(seconds)s").tag(seconds)
          }
        }
        .pickerStyle(.menu)
        .labelsHidden()
      }

      Text("Last check \(viewModel.statusText)")
        .font(.caption)
        .foregroundStyle(.secondary)

      if !viewModel.isExperimentalMode, let tokenCost = viewModel.lastRefreshTokenCost {
        let burnText = viewModel.estimatedHourlyTokenBurnPercent
          .map { " • ~\($0.formatted(.number.precision(.fractionLength(2))))%/h \(viewModel.burnTrendSymbol)" } ?? ""
        Text("Cost \(tokenCost)t\(burnText)")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }

      HStack(spacing: 8) {
        Button("Reload now") {
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

}
