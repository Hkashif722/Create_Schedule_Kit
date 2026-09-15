//
//  CSChipFlowPackerTests.swift
//  Create_Schedule_KitTests
//
//  Pins the chip wrapping used by the trainer/tag chips. The bug this replaces:
//  an adaptive LazyVGrid gave every chip the same column width, so a long trainer
//  chip such as "Chetan Wade II-cw (Internal)" was truncated to "Chetan… ✕". Chips
//  are now packed by their own measured widths.
//

import CoreGraphics
import Testing
@testable import Create_Schedule_Kit

@Suite struct CSChipFlowPackerTests {

    private struct Chip: Identifiable, Equatable {
        let id: String
    }

    private func pack(
        _ widths: [(String, CGFloat)],
        available: CGFloat,
        spacing: CGFloat = 8
    ) -> [[String]] {
        let items = widths.map { Chip(id: $0.0) }
        let measured = Dictionary(uniqueKeysWithValues: widths)
        return CSChipFlowPacker.rows(items, widths: measured, available: available, spacing: spacing)
            .map { $0.map(\.id) }
    }

    @Test("Chips that fit share a row")
    func packsRow() {
        let rows = pack([("a", 150), ("b", 150), ("c", 150)], available: 320)
        #expect(rows == [["a", "b"], ["c"]])  // 150 + 8 + 150 fits 320; a third would not
    }

    @Test("Spacing counts against the row width")
    func spacingCounts() {
        #expect(pack([("a", 156), ("b", 156)], available: 320) == [["a", "b"]])
        #expect(pack([("a", 157), ("b", 157)], available: 320) == [["a"], ["b"]])
    }

    @Test("A chip wider than the container keeps its own row instead of being boxed into a column")
    func oversizedChipGetsOwnRow() {
        let rows = pack([("short", 60), ("Chetan Wade II-cw (Internal)", 400)], available: 320)
        #expect(rows == [["short"], ["Chetan Wade II-cw (Internal)"]])
    }

    @Test("Unmeasured chips are treated as full width")
    func unmeasuredChipsGetOwnRow() {
        let items = [Chip(id: "a"), Chip(id: "b")]
        let rows = CSChipFlowPacker.rows(items, widths: ["a": 40], available: 320, spacing: 8)
        #expect(rows.map { $0.map(\.id) } == [["a"], ["b"]])
    }

    @Test("Before the container width is known every chip gets a line")
    func unknownWidthFallsBackToOnePerLine() {
        let items = [Chip(id: "a"), Chip(id: "b")]
        let rows = CSChipFlowPacker.rows(items, widths: [:], available: 0, spacing: 8)
        #expect(rows.map { $0.map(\.id) } == [["a"], ["b"]])
    }

    @Test("No items, no rows")
    func emptyInput() {
        #expect(pack([], available: 320).isEmpty)
    }
}
