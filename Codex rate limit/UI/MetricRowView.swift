import SwiftUI

struct MetricRowView: View {
  let title: String
  let value: String

  var body: some View {
    HStack {
      Text(title)
        .foregroundStyle(.secondary)
      Spacer()
      Text(value)
    }
    .font(.system(size: 12, weight: .medium, design: .rounded))
  }
}
