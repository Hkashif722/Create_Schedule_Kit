import Testing
import Foundation
@testable import Create_Schedule_Kit

@Suite struct WebinarLinkRulesTests {

    // MARK: - Which provider asks for a link

    @Test func onlyTeamsAsksForALinkByHand() {
        #expect(WebinarLinkRules.usesStaticLink(for: .teams, isEnabled: true))
        #expect(WebinarLinkRules.usesStaticLink(for: .zoom, isEnabled: true) == false)
        #expect(WebinarLinkRules.usesStaticLink(for: .googleMeet, isEnabled: true) == false)
        #expect(WebinarLinkRules.usesStaticLink(for: .gotoMeeting, isEnabled: true) == false)
        #expect(WebinarLinkRules.usesStaticLink(for: nil, isEnabled: true) == false)
    }

    @Test func teamsAsksForNothingWhileTheConfigIsOff() {
        #expect(WebinarLinkRules.usesStaticLink(for: .teams, isEnabled: false) == false)
    }

    // MARK: - Pasted link text

    @Test func hardWrappedPasteIsFlattenedToOneLine() {
        let pasted = """
        https://teams.microsoft.com/l/meetup-join/19%3ameeting_ABC
        %40thread.v2/0?context=%7b%22Tid%22%3a%22xyz%22%7d
        """
        let normalized = WebinarLinkRules.normalizedLink(pasted)

        #expect(!normalized.contains("\n"))
        #expect(normalized.hasPrefix("https://teams.microsoft.com/l/meetup-join/"))
        #expect(WebinarLinkRules.isValidLink(pasted))
    }

    @Test func percentEncodingSurvivesNormalization() {
        let link = "https://teams.microsoft.com/l/meetup-join/19%3ameeting_A%40thread.v2/0?context=%7b%22Tid%22%7d"
        #expect(WebinarLinkRules.normalizedLink(link) == link)
    }

    @Test func mailClientWrappersAreStripped() {
        #expect(WebinarLinkRules.normalizedLink("<https://team.link>") == "https://team.link")
        #expect(WebinarLinkRules.normalizedLink("\"https://team.link\"") == "https://team.link")
        #expect(WebinarLinkRules.normalizedLink("  https://team.link  ") == "https://team.link")
    }

    @Test func zeroWidthCharactersAreStripped() {
        let withZeroWidth = "https://team\u{200B}.link\u{FEFF}"
        #expect(WebinarLinkRules.normalizedLink(withZeroWidth) == "https://team.link")
    }

    // MARK: - Validation (deliberately permissive)

    @Test func acceptsTheValueUatSignsOffWith() {
        // Capital scheme, and not a Teams host at all — a host allow-list would reject it.
        #expect(WebinarLinkRules.isValidLink("Https://team.link"))
    }

    @Test func acceptsALongZoomStartUrl() {
        let startURL = "https://us05web.zoom.us/s/84826985680?zak=eyJ0eXAiOiJKV1QiLCJzdiI6IjAwMDAwMiIsInptX3NrbSI6InptX28ybSJ9.abc-DEF_123"
        #expect(WebinarLinkRules.isValidLink(startURL))
        #expect(startURL.count > 100)
    }

    @Test func acceptsSafeLinksRewrittenUrls() {
        // What a link copied out of Outlook actually looks like once Defender rewrites it.
        let safeLink = "https://eur01.safelinks.protection.outlook.com/?url=https%3A%2F%2Fteams.microsoft.com%2Fl%2Fmeetup-join%2F19"
        #expect(WebinarLinkRules.isValidLink(safeLink))
    }

    @Test(arguments: ["", "   ", "\n", "team.link", "javascript:alert(1)", "https://localhost", "mailto:a@b.com"])
    func rejectsAnythingThatIsNotAnHttpUrlWithAHost(_ value: String) {
        #expect(WebinarLinkRules.isValidLink(value) == false)
    }
}
