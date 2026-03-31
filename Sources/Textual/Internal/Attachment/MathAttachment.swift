import SwiftUI
@_spi(Textual) private import SwiftUIMath

struct MathAttachment: Attachment {
  enum DisplayStyle: Sendable {
    case inline
    case block
  }

  var description: String {
    switch displayStyle {
    case .inline:
      return "$\(latex)$"
    case .block:
      return "$$\(latex)$$"
    }
  }

  var selectionStyle: AttachmentSelectionStyle {
    .text
  }

  let latex: String
  let displayStyle: DisplayStyle

  init(latex: String, style: DisplayStyle) {
    self.latex = latex
    self.displayStyle = style
  }

  var body: some View {
    MathView(latex: latex, style: displayStyle)
  }

  func baselineOffset(in environment: TextEnvironmentValues) -> CGFloat {
    // Return 0 for fallback (Text handles its own baseline)
    // wangqi modified 2026-03-31
    let bounds = typographicBounds(in: environment)
    guard bounds.size.width > 0 else { return 0 }
    return -bounds.descent
  }

  func sizeThatFits(_ proposal: ProposedViewSize, in environment: TextEnvironmentValues) -> CGSize {
    let bounds = typographicBounds(fitting: proposal, in: environment)
    // Fallback: estimate monospaced text size when parse fails
    // wangqi modified 2026-03-31
    guard bounds.size.width > 0 else {
      let text = displayStyle == .block ? "$$\(latex)$$" : "$\(latex)$"
      let fontSize = FontScaled(environment.mathProperties.fontScale).resolve(in: environment) * 0.7
      let charWidth = fontSize * 0.6
      let width = min(CGFloat(text.count) * charWidth, proposal.width ?? 300)
      let height = fontSize * 1.4
      return CGSize(width: width, height: height)
    }
    return bounds.size
  }

  private func typographicBounds(
    fitting proposal: ProposedViewSize = .unspecified,
    in environment: TextEnvironmentValues
  ) -> Math.TypographicBounds {
    Math.typographicBounds(
      for: latex,
      fitting: proposal,
      font: .init(
        name: .init(environment.mathProperties.fontName),
        size: FontScaled(environment.mathProperties.fontScale).resolve(in: environment)
      ),
      style: .init(displayStyle)
    )
  }
}

private struct MathView: View {
  @Environment(\.textEnvironment) private var environment

  let latex: String
  let style: MathAttachment.DisplayStyle

  var body: some View {
    // Show raw LaTeX as fallback when the expression fails to parse
    // wangqi modified 2026-03-31
    let fontSize = FontScaled(environment.mathProperties.fontScale).resolve(in: environment)
    let bounds = Math.typographicBounds(
      for: latex,
      fitting: .unspecified,
      font: .init(
        name: .init(environment.mathProperties.fontName),
        size: fontSize
      ),
      style: .init(style)
    )
    if bounds.size.width > 0 {
      Math(latex)
        .mathFont(
          .init(
            name: .init(environment.mathProperties.fontName),
            size: fontSize
          )
        )
        .mathTypesettingStyle(.init(style))
        .mathRenderingMode(.monochrome)
    } else {
      let fallbackText = style == .block ? "$$\(latex)$$" : "$\(latex)$"
      Text(fallbackText)
        .font(.system(.caption, design: .monospaced))
        .foregroundStyle(.secondary)
        .accessibilityLabel("Math expression")
        .accessibilityValue(latex)
    }
  }
}

extension Math.Font.Name {
  fileprivate init(_ fontName: MathProperties.FontName) {
    self.init(rawValue: fontName.rawValue)
  }
}

extension Math.TypesettingStyle {
  fileprivate init(_ style: MathAttachment.DisplayStyle) {
    switch style {
    case .inline:
      self = .text
    case .block:
      self = .display
    }
  }
}
