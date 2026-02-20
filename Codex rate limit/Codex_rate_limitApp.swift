import AppKit
import SwiftUI

@main
struct CodexRateLimitApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @StateObject private var viewModel: RateLimitViewModel

  init() {
    let environment = AppEnvironment.live()
    _viewModel = StateObject(wrappedValue: RateLimitViewModel(environment: environment))
  }

  var body: some Scene {
    MenuBarExtra {
      MainMenuView(viewModel: viewModel)
    } label: {
      MenuBarLabelView(viewModel: viewModel)
    }
    .menuBarExtraStyle(.window)
  }
}

