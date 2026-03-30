import SwiftUI

extension StructuredText {
  struct Heading: View {
    @Environment(\.headingStyle) private var headingStyle

    private let content: AttributedSubstring
    private let level: Int

    init(_ content: AttributedSubstring, level: Int) {
      self.content = content
      self.level = level
    }

    var body: some View {
      let configuration = HeadingStyleConfiguration(
        label: .init(label),
        indentationLevel: indentationLevel,
        headingLevel: level
      )
      let resolvedStyle = headingStyle.resolve(configuration: configuration)

      // Remove .id(content.slugified()) to prevent view identity destruction during streaming
      // wangqi modified 2026-03-30
      AnyView(resolvedStyle)
    }

    private var label: some View {
      WithInlineStyle(AttributedString(content)) {
        TextFragment($0)
      }
    }

    private var indentationLevel: Int {
      content.presentationIntent?.indentationLevel ?? 0
    }
  }
}
