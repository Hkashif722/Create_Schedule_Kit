//
//  CSChipFlow.swift
//  Create_Schedule_Kit
//
//  Wrapping (flow) layout for chips.
//

import SwiftUI

/// Lays chips out left-to-right and wraps to a new line when the next chip no longer fits.
///
/// `LazyVGrid(.adaptive(minimum:))` splits the row into equal-width columns, so a chip whose
/// title is wider than its column is truncated ("Chetan… ✕") even when the row still has free
/// space. This container sizes every chip to its own content instead, so a long title such as
/// "Chetan Wade II-cw (Internal)" stays readable and only truncates when it is wider than the
/// whole container.
///
/// The `Layout` protocol would express this directly but is iOS 16+, and this package targets
/// iOS 15 — so chips are measured off-screen at their ideal size and the rows are packed from
/// those measurements. Before the first measurement lands each chip gets its own line, which is
/// never truncated; the reflow happens on the same frame the sizes arrive.
struct CSChipFlow<Item: Identifiable, Content: View>: View {

    private let items: [Item]
    private let spacing: CGFloat
    private let lineSpacing: CGFloat
    private let content: (Item) -> Content

    @State private var sizes: [Item.ID: CGSize] = [:]
    @State private var availableWidth: CGFloat = 0

    init(
        _ items: [Item],
        spacing: CGFloat = 8,
        lineSpacing: CGFloat = 8,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.spacing = spacing
        self.lineSpacing = lineSpacing
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: lineSpacing) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                // A chip wider than the row is proposed less than its ideal width by the HStack
                // and truncates itself — nothing overflows the card.
                HStack(spacing: spacing) {
                    ForEach(row) { item in
                        content(item)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(widthReader)
        .background(measuringLayer)
    }

    /// Reports the container width without influencing it.
    private var widthReader: some View {
        GeometryReader { proxy in
            Color.clear
                .preference(key: CSChipFlowWidthKey.self, value: proxy.size.width)
        }
        .onPreferenceChange(CSChipFlowWidthKey.self) { width in
            if abs(width - availableWidth) > 0.5 { availableWidth = width }
        }
    }

    /// Off-screen copy of every chip at its ideal size, used only to measure. Pinned to a zero
    /// frame so it adds nothing to the layout.
    private var measuringLayer: some View {
        ZStack {
            ForEach(items) { item in
                content(item)
                    .fixedSize()
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: CSChipFlowSizeKey<Item.ID>.self,
                                value: [item.id: proxy.size]
                            )
                        }
                    )
            }
        }
        .frame(width: 0, height: 0)
        .clipped()
        .hidden()
        .accessibilityHidden(true)
        .onPreferenceChange(CSChipFlowSizeKey<Item.ID>.self) { sizes = $0 }
    }

    private var rows: [[Item]] {
        CSChipFlowPacker.rows(items, widths: sizes.mapValues(\.width), available: availableWidth, spacing: spacing)
    }
}

/// Row packing for `CSChipFlow`, split out so it can be tested without a rendered view.
enum CSChipFlowPacker {

    /// Greedily fills each row until the next chip no longer fits, then starts a new one.
    /// Chips are never split; one wider than the container gets a row to itself and truncates.
    static func rows<Item: Identifiable>(
        _ items: [Item],
        widths: [Item.ID: CGFloat],
        available: CGFloat,
        spacing: CGFloat
    ) -> [[Item]] {
        // Before the container width is known, one chip per line — wrong-looking for a frame,
        // but never truncated.
        guard available > 0 else { return items.map { [$0] } }

        var rows: [[Item]] = []
        var currentWidth: CGFloat = 0

        for item in items {
            // An unmeasured chip is assumed full width so it never lands in a row it cannot fit.
            let width = min(widths[item.id] ?? available, available)
            if !(rows.last?.isEmpty ?? true), currentWidth + spacing + width <= available {
                rows[rows.count - 1].append(item)
                currentWidth += spacing + width
            } else {
                rows.append([item])
                currentWidth = width
            }
        }
        return rows
    }
}

private struct CSChipFlowWidthKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct CSChipFlowSizeKey<ID: Hashable>: PreferenceKey {
    static var defaultValue: [ID: CGSize] { [:] }
    static func reduce(value: inout [ID: CGSize], nextValue: () -> [ID: CGSize]) {
        value.merge(nextValue()) { _, new in new }
    }
}
