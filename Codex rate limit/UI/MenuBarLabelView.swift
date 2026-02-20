import AppKit
import SwiftUI

struct MenuBarLabelView: View {
  @ObservedObject var viewModel: RateLimitViewModel

  var body: some View {
    Image(nsImage: menuBarImage())
      .renderingMode(.original)
      .interpolation(.none)
  }

  private func displayedUsedPercent(fromUsedPercent usedPercent: Double?) -> Double {
    guard let usedPercent else { return 0 }
    return max(0, min(100, usedPercent))
  }

  private func displayedUsedFraction(fromUsedPercent usedPercent: Double?) -> Double {
    displayedUsedPercent(fromUsedPercent: usedPercent) / 100.0
  }

  private func navProgressColor(fromUsedPercent usedPercent: Double?) -> NSColor {
    let displayedUsedPercent = displayedUsedPercent(fromUsedPercent: usedPercent)
    if displayedUsedPercent >= 60 {
      return .systemRed
    }
    if displayedUsedPercent >= 30 {
      return .systemOrange
    }
    return .systemGreen
  }

  private func menuBarImage() -> NSImage {
    let size = NSSize(width: 110, height: 28)
    let image = NSImage(size: size)
    image.lockFocus()
    defer { image.unlockFocus() }

    let barWidth: CGFloat = 72
    let barHeight: CGFloat = 5
    let horizontalGap: CGFloat = 7
    let topRowBarY: CGFloat = 16
    let bottomRowBarY: CGFloat = 3

    let primaryText = rowText(usedPercent: viewModel.snapshot?.codexPrimaryUsedPercent)
    let secondaryText = rowText(usedPercent: viewModel.snapshot?.codexSecondaryUsedPercent)

    let attributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .bold),
      .foregroundColor: NSColor.labelColor,
    ]

    let textColumnWidth = max(
      (primaryText as NSString).size(withAttributes: attributes).width,
      (secondaryText as NSString).size(withAttributes: attributes).width
    )
    let contentWidth = barWidth + horizontalGap + textColumnWidth
    let contentOriginX = floor((size.width - contentWidth) / 2)
    let textX = contentOriginX + barWidth + horizontalGap

    drawCapsuleBar(
      rect: NSRect(x: contentOriginX, y: topRowBarY, width: barWidth, height: barHeight),
      fraction: displayedUsedFraction(fromUsedPercent: viewModel.snapshot?.codexPrimaryUsedPercent),
      fillColor: navProgressColor(fromUsedPercent: viewModel.snapshot?.codexPrimaryUsedPercent)
    )
    drawCapsuleBar(
      rect: NSRect(x: contentOriginX, y: bottomRowBarY, width: barWidth, height: barHeight),
      fraction: displayedUsedFraction(fromUsedPercent: viewModel.snapshot?.codexSecondaryUsedPercent),
      fillColor: navProgressColor(fromUsedPercent: viewModel.snapshot?.codexSecondaryUsedPercent)
    )

    let primaryTextHeight = (primaryText as NSString).size(withAttributes: attributes).height
    let secondaryTextHeight = (secondaryText as NSString).size(withAttributes: attributes).height

    (primaryText as NSString).draw(
      at: NSPoint(x: textX, y: topRowBarY + ((barHeight - primaryTextHeight) / 2)),
      withAttributes: attributes
    )
    (secondaryText as NSString).draw(
      at: NSPoint(x: textX, y: bottomRowBarY + ((barHeight - secondaryTextHeight) / 2)),
      withAttributes: attributes
    )

    image.isTemplate = false
    return image
  }

  private func drawCapsuleBar(rect: NSRect, fraction: Double, fillColor: NSColor) {
    let clamped = max(0, min(1, fraction))
    let trackPath = NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2)
    NSColor.labelColor.withAlphaComponent(0.22).setFill()
    trackPath.fill()

    let filledWidth = clamped > 0 ? max(1, rect.width * clamped) : 0
    if filledWidth > 0 {
      let filledRect = NSRect(x: rect.minX, y: rect.minY, width: filledWidth, height: rect.height)
      let fillPath = NSBezierPath(roundedRect: filledRect, xRadius: rect.height / 2, yRadius: rect.height / 2)
      fillColor.setFill()
      fillPath.fill()
    }
  }

  private func rowText(usedPercent: Double?) -> String {
    let value = Int(displayedUsedPercent(fromUsedPercent: usedPercent).rounded())
    return "\(value)%"
  }
}
