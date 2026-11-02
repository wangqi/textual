import SwiftUI

// MARK: - Overview
//
// Table uses a two-pass layout system. The first pass renders cells which emit their bounds via
// preferences. The second pass collects all cell bounds, transforms them from anchor coordinates
// to geometry coordinates, and builds a `TableLayout` that the style uses to render overlays
// (such as grid lines) and backgrounds with precise cell positions.

extension StructuredText {
  struct Table: View {
    @Environment(\.tableStyle) private var tableStyle

    // Initialize with the value all bundled styles emit (borderWidth=1) so the first render
    // already uses 1pt spacing. When onPreferenceChange fires with Spacing(1,1), SwiftUI
    // detects no state change (Hashable equality) and skips the second render pass that
    // previously caused height instability and scroll-position jumps in the parent chat view.
    // wangqi modified 2026-03-29
    @State private var spacing = TableCell.Spacing(horizontal: 1, vertical: 1)

    private let intent: PresentationIntent.IntentType?
    private let content: AttributedSubstring
    private let columns: [PresentationIntent.TableColumn]

    init(
      intent: PresentationIntent.IntentType?,
      content: AttributedSubstring,
      columns: [PresentationIntent.TableColumn]
    ) {
      self.intent = intent
      self.content = content
      self.columns = columns
    }

    var body: some View {
      let configuration = TableStyleConfiguration(
        label: .init(label),
        indentationLevel: indentationLevel
      )
      let resolvedStyle = tableStyle.resolve(configuration: configuration)
        .onPreferenceChange(TableCell.SpacingKey.self) { @MainActor in
          spacing = $0
        }

      AnyView(resolvedStyle)
    }

    @ViewBuilder
    private var label: some View {
      let rowRuns = content.blockRuns(parent: intent)

      Grid(horizontalSpacing: spacing.horizontal, verticalSpacing: spacing.vertical) {
        ForEach(rowRuns.indices, id: \.self) { rowIndex in
          let rowRun = rowRuns[rowIndex]
          let rowContent = content[rowRun.range]
          let columnRuns = rowContent.blockRuns(parent: rowRun.intent)
          // Foundation emits no run for an empty cell, so placing cells by run position shifted every later cell
          // one column left (`| | A | B |` drew A over the first column). Place each cell by its own column index
          // and draw an empty cell in each gap. // wangqi modified 2026-10-27
          let slots = Self.cellSlots(for: columnRuns, columnCount: columns.count)

          GridRow {
            ForEach(slots.indices, id: \.self) { columnIndex in
              if let runIndex = slots[columnIndex] {
                let cellRun = columnRuns[runIndex]
                let cellContent = rowContent[cellRun.range]

                TableCell(cellContent, row: rowIndex, column: columnIndex)
                  .gridColumnAlignment(alignment(for: columnIndex))
              } else {
                TableCell(Self.emptyCellContent, row: rowIndex, column: columnIndex)
                  .gridColumnAlignment(alignment(for: columnIndex))
              }
            }
          }
        }
      }
    }

    private var indentationLevel: Int {
      content.runs.first?.presentationIntent?.indentationLevel ?? 0
    }

    // Maps each grid column to the index of the cell run that fills it, nil for an empty cell Foundation left out.
    // Falls back to run order when a run carries no table-cell column index. // wangqi modified 2026-10-27
    nonisolated static func cellSlots(for columnRuns: AttributedString.BlockRuns, columnCount: Int) -> [Int?] {
      var cellColumns: [Int] = []
      for run in columnRuns {
        guard case .tableCell(let columnIndex) = run.intent?.kind, columnIndex >= 0 else {
          return columnRuns.indices.map { Optional($0) }
        }
        cellColumns.append(columnIndex)
      }
      let width = max(columnCount, (cellColumns.max() ?? -1) + 1)
      var slots = [Int?](repeating: nil, count: width)
      for (runIndex, columnIndex) in cellColumns.enumerated() where slots[columnIndex] == nil {
        slots[columnIndex] = runIndex
      }
      return slots
    }

    // wangqi modified 2026-10-27
    private static var emptyCellContent: AttributedSubstring {
      let empty = AttributedString()
      return empty[empty.startIndex..<empty.endIndex]
    }

    private func alignment(for columnIndex: Int) -> HorizontalAlignment {
      guard columnIndex < columns.count else {
        return .leading
      }

      switch columns[columnIndex].alignment {
      case .left:
        return .leading
      case .center:
        return .center
      case .right:
        return .trailing
      @unknown default:
        return .leading
      }
    }
  }
}
