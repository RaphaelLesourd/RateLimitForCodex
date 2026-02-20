import SwiftUI

struct MainMenuView: View {
  @ObservedObject var viewModel: RateLimitViewModel
  @State private var isShowingAbout = false

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      if let snapshot = viewModel.snapshot {
        if viewModel.isExperimentalMode,
           snapshot.sessionPrimaryUsedPercent != nil || snapshot.sessionSecondaryUsedPercent != nil
        {
          CodexProgressSectionView(snapshot: snapshot)
        } else {
          MetricRowView(title: "Requests", value: "\(snapshot.requestsRemaining?.description ?? "--") / \(snapshot.requestsLimit?.description ?? "--")")
          MetricRowView(title: "Request reset", value: snapshot.requestsReset ?? "--")
          MetricRowView(title: "Tokens", value: "\(snapshot.tokensRemaining?.description ?? "--") / \(snapshot.tokensLimit?.description ?? "--")")
          MetricRowView(title: "Token reset", value: snapshot.tokensReset ?? "--")
        }
      } else {
        Text(viewModel.isExperimentalMode ? "No local session rate-limit data yet." : "No API rate limit data yet.")
          .foregroundStyle(.secondary)
      }

      if let errorText = viewModel.errorText {
        Text(errorText)
          .font(.caption)
          .foregroundStyle(.red)
          .fixedSize(horizontal: false, vertical: true)
      }

      Divider()

      AuthenticationSectionView(viewModel: viewModel)

      Divider()

      AutoRefreshSectionView(viewModel: viewModel)

      Divider()

      HStack(spacing: 12) {
        Button("About") {
          isShowingAbout = true
        }

        Spacer()

        Button("Quit") {
          viewModel.quit()
        }
      }
    }
    .padding(12)
    .frame(width: 340)
    .sheet(isPresented: $isShowingAbout) {
      AboutSupportView(isPresented: $isShowingAbout)
    }
    .onDisappear {
      isShowingAbout = false
    }
  }
}

private enum AppSupportInfo {
  static let email = "raphparis@icloud.com"
}

private struct AboutSupportView: View {
  @Binding var isPresented: Bool

  private var appName: String {
    (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
      ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)
      ?? "Rate Limit Monitor"
  }

  private var version: String {
    (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0"
  }

  private var build: String {
    (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "1"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(appName)
        .font(.title3.weight(.semibold))
      Text("⚠️ Not affiliated with OpenAI.")
      Group {
        Text("Copyright (c) 2026 Raph - Version \(version) (\(build))")
        Text("Created with Codex.")

      }
      .font(.caption)
      .foregroundStyle(.secondary)
      Divider()

      VStack(alignment: .leading, spacing: 4) {
        Text("Support")
          .font(.headline)

        if let supportURL = URL(string: "mailto:\(AppSupportInfo.email)") {
          Link(AppSupportInfo.email, destination: supportURL)
            .textSelection(.enabled)
        } else {
          Text(AppSupportInfo.email)
            .textSelection(.enabled)
        }
      }

      HStack {
        Spacer()
        Button("Done") {
          isPresented = false
        }
        .keyboardShortcut(.defaultAction)
      }
    }
    .padding(16)
    .frame(width: 360)
  }
}
