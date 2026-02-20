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
          MetricRowView(
            title: String(localized: "main_menu.metric.requests"),
            value: "\(valueOrPlaceholder(snapshot.requestsRemaining?.description)) / \(valueOrPlaceholder(snapshot.requestsLimit?.description))"
          )
          MetricRowView(
            title: String(localized: "main_menu.metric.request_reset"),
            value: valueOrPlaceholder(snapshot.requestsReset)
          )
          MetricRowView(
            title: String(localized: "main_menu.metric.tokens"),
            value: "\(valueOrPlaceholder(snapshot.tokensRemaining?.description)) / \(valueOrPlaceholder(snapshot.tokensLimit?.description))"
          )
          MetricRowView(
            title: String(localized: "main_menu.metric.token_reset"),
            value: valueOrPlaceholder(snapshot.tokensReset)
          )
        }
      } else {
        Text(
          viewModel.isExperimentalMode
            ? String(localized: "main_menu.no_data.local_session")
            : String(localized: "main_menu.no_data.api")
        )
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

      Toggle(
        String(localized: "main_menu.open_at_login"),
        isOn: Binding(
          get: { viewModel.launchAtLoginEnabled },
          set: { viewModel.setLaunchAtLoginEnabled($0) }
        )
      )

      if let launchAtLoginErrorText = viewModel.launchAtLoginErrorText {
        Text(launchAtLoginErrorText)
          .font(.caption)
          .foregroundStyle(.red)
          .fixedSize(horizontal: false, vertical: true)
      }

      Divider()

      HStack(spacing: 12) {
        Button(String(localized: "common.button.about")) {
          isShowingAbout = true
        }

        Spacer()

        Button(String(localized: "common.button.quit")) {
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
      ?? String(localized: "main_menu.about.app_name_fallback")
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
      Text(String(localized: "main_menu.about.disclaimer"))
      Group {
        Text(localizedFormat("main_menu.about.copyright_format", version, build))
        Text(String(localized: "main_menu.about.created_with_codex"))

      }
      .font(.caption)
      .foregroundStyle(.secondary)
      Divider()

      VStack(alignment: .leading, spacing: 4) {
        Text(String(localized: "main_menu.about.support"))
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
        Button(String(localized: "common.button.done")) {
          isPresented = false
        }
        .keyboardShortcut(.defaultAction)
      }
    }
    .padding(16)
    .frame(width: 360)
  }

  private func localizedFormat(_ key: String.LocalizationValue, _ arguments: CVarArg...) -> String {
    String(format: String(localized: key), locale: Locale.current, arguments: arguments)
  }
}

private func valueOrPlaceholder(_ value: String?) -> String {
  value ?? String(localized: "common.placeholder.unavailable")
}
