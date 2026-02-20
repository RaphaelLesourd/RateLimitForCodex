import SwiftUI

struct AuthenticationSectionView: View {
  @ObservedObject var viewModel: RateLimitViewModel
  @Binding var selectedAuthMode: RateLimitViewModel.AuthMode

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Authentication")
        .font(.system(size: 14, weight: .bold, design: .rounded))
        .foregroundStyle(.primary)

      Picker("", selection: $selectedAuthMode) {
        Text("Codex app").tag(RateLimitViewModel.AuthMode.codexLogin)
        Text("API key").tag(RateLimitViewModel.AuthMode.apiKey)
      }
      .pickerStyle(.segmented)
      .labelsHidden()

      if viewModel.authMode == .codexLogin {
        VStack(alignment: .leading, spacing: 6) {
          Text(codexLoginText)
            .font(.system(size: 12, weight: .regular, design: .rounded))
            .foregroundStyle(.secondary)

          if !viewModel.codexLoginAvailable {
            Text("Email/password login happens in your browser. Click Log in to Codex, then return here.")
              .font(.caption)
              .foregroundStyle(.secondary)

            if let loginURL = URL(string: "https://chatgpt.com/auth/login") {
              Link("Log in to Codex", destination: loginURL)
                .buttonStyle(.borderedProminent)
            }
          }
        }
      } else {
        SecureField("OpenAI API key", text: $viewModel.apiKey)
          .textFieldStyle(.roundedBorder)
      }
    }
  }

  private var codexLoginText: String {
    if let email = viewModel.codexAccountEmail {
      return "Signed in as \(email)"
    }
    if viewModel.codexSessionOnly {
      return "Session detected from recent Codex usage"
    }
    if viewModel.codexLoginAvailable {
      return "Signed in via Codex app"
    }
    return "No Codex session detected"
  }
}
