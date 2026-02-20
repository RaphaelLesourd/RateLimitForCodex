import SwiftUI

struct AuthenticationSectionView: View {
  @ObservedObject var viewModel: RateLimitViewModel

  private var dataCollectionModeBinding: Binding<RateLimitViewModel.DataCollectionMode> {
    Binding(
      get: { viewModel.dataCollectionMode },
      set: { viewModel.setDataCollectionMode($0) }
    )
  }

  private var apiKeyBinding: Binding<String> {
    Binding(
      get: { viewModel.apiKey },
      set: { viewModel.setAPIKey($0) }
    )
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Data Source")
        .font(.system(size: 14, weight: .bold, design: .rounded))
        .foregroundStyle(.primary)

      Picker("", selection: dataCollectionModeBinding) {
        Text(RateLimitViewModel.DataCollectionMode.officialAPI.title)
          .tag(RateLimitViewModel.DataCollectionMode.officialAPI)
        Text(RateLimitViewModel.DataCollectionMode.experimentalLocalSession.title)
          .tag(RateLimitViewModel.DataCollectionMode.experimentalLocalSession)
      }
      .pickerStyle(.segmented)
      .labelsHidden()

      if viewModel.isExperimentalMode {
        Text("Experimental mode reads local session files from ~/.codex/sessions. This path is not an official OpenAI API integration.")
          .font(.caption)
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      } else {
        Text("Official OpenAI API key")
          .font(.caption)
          .foregroundStyle(.secondary)

        SecureField("OpenAI API key", text: apiKeyBinding)
          .textFieldStyle(.roundedBorder)

        if let apiKeysURL = URL(string: "https://platform.openai.com/api-keys") {
          Link("Manage API keys", destination: apiKeysURL)
            .font(.caption)
        }
      }
    }
  }
}
