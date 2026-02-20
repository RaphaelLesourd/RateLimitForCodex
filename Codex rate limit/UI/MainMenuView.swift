import SwiftUI

struct MainMenuView: View {
  @ObservedObject var viewModel: RateLimitViewModel
  @State private var selectedAuthMode: RateLimitViewModel.AuthMode = .apiKey

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      if let snapshot = viewModel.snapshot {
        if viewModel.authMode == .codexLogin, snapshot.codexPrimaryUsedPercent != nil {
          CodexProgressSectionView(snapshot: snapshot)
        } else {
          MetricRowView(title: "Requests", value: "\(snapshot.requestsRemaining?.description ?? "--") / \(snapshot.requestsLimit?.description ?? "--")")
          MetricRowView(title: "Request reset", value: snapshot.requestsReset ?? "--")
          MetricRowView(title: "Tokens", value: "\(snapshot.tokensRemaining?.description ?? "--") / \(snapshot.tokensLimit?.description ?? "--")")
          MetricRowView(title: "Token reset", value: snapshot.tokensReset ?? "--")
        }
      } else {
        Text("No rate limit data yet.")
          .foregroundStyle(.secondary)
      }

      if let errorText = viewModel.errorText {
        Text(errorText)
          .font(.caption)
          .foregroundStyle(.red)
          .fixedSize(horizontal: false, vertical: true)
      }

      Divider()

      AuthenticationSectionView(viewModel: viewModel, selectedAuthMode: $selectedAuthMode)

      Divider()

      AutoRefreshSectionView(viewModel: viewModel)

      Divider()

      HStack(spacing: 12) {
        Spacer()

        Button("Quit") {
          viewModel.quit()
        }
      }
    }
    .padding(12)
    .frame(width: 340)
    .onAppear {
      selectedAuthMode = viewModel.authMode
    }
    .onChange(of: viewModel.authMode) { _, newMode in
      if selectedAuthMode != newMode {
        selectedAuthMode = newMode
      }
    }
    .onChange(of: selectedAuthMode) { _, newMode in
      guard newMode != viewModel.authMode else { return }
      Task { @MainActor in
        switch newMode {
          case .codexLogin:
            viewModel.useCodexLogin()
          case .apiKey:
            viewModel.useAPIKeyLogin()
        }
      }
    }
  }
}
