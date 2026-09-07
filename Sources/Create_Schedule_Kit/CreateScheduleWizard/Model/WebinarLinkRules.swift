//
//  WebinarLinkRules.swift
//  Create_Schedule_Kit
//
//  Pure, testable rules for the hand-entered Microsoft Teams meeting link on Step 1 (no
//  UI / router dependencies). Teams is the only provider with a link field, and only while
//  `ATPTLWCS` is on — every other provider is untouched by this feature.
//

import Foundation

enum WebinarLinkRules {

    /// Longest link the text field accepts. `MultilineTextInputField` defaults to 250,
    /// which silently truncates a real Teams `meetup-join` link — its `context=` query
    /// alone runs past that.
    static let maxLinkCharacters = 2_000

    /// Teams asks for a link by hand; nothing else does.
    static func usesStaticLink(for type: WebinarType?, isEnabled: Bool) -> Bool {
        type == .teams && isEnabled
    }

    // MARK: - Link text

    /// Links arrive pasted from Outlook, Teams and mail clients, which wrap them in angle
    /// brackets or quotes, hard-wrap long URLs across lines, and inject zero-width
    /// characters. A URL never legitimately contains whitespace, so all of it goes.
    /// Percent-encoding (`%3a`, `%7b`) is left alone.
    static func normalizedLink(_ raw: String) -> String {
        // Whitespace goes first: a trailing newline would otherwise shield the closing
        // bracket of a `<https://…>` paste from the wrapper trim.
        let stripped = raw.unicodeScalars
            .filter { !CharacterSet.whitespacesAndNewlines.contains($0) && !zeroWidthScalars.contains($0) }
            .reduce(into: "") { $0.unicodeScalars.append($1) }
        return stripped.trimmingCharacters(in: CharacterSet(charactersIn: "<>\"'"))
    }

    /// Zero-width space / non-joiner / joiner / BOM — invisible, and enough to break a URL.
    private static let zeroWidthScalars: Set<Unicode.Scalar> = [
        "\u{200B}", "\u{200C}", "\u{200D}", "\u{FEFF}"
    ]

    /// Deliberately permissive: a non-empty http(s) URL with a host is all that is required.
    ///
    /// Hosts are never checked. Tenants paste vanity links, `teams.live.com` links and
    /// Defender Safe Links-rewritten URLs, and the value UAT signs off with is
    /// `Https://team.link` — capital scheme, not a Teams host — so a stricter rule would
    /// reject links the business considers valid.
    static func isValidLink(_ raw: String) -> Bool {
        let value = normalizedLink(raw)
        guard !value.isEmpty,
              let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host, host.contains(".")
        else { return false }
        return true
    }
}
