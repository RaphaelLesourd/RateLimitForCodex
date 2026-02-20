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
      Text(String(localized: "auth.data_source"))
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
        Text(String(localized: "auth.experimental.notice"))
          .font(.caption)
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      } else {
        Text(String(localized: "auth.official.label"))
          .font(.caption)
          .foregroundStyle(.secondary)

        SecureField(String(localized: "auth.api_key.placeholder"), text: apiKeyBinding)
          .textFieldStyle(.roundedBorder)

        if let apiKeysURL = URL(string: "https://platform.openai.com/api-keys") {
          Link(String(localized: "auth.api_key.manage"), destination: apiKeysURL)
            .font(.caption)
        }
      }
    }
  }
}
