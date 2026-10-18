import Foundation

/// ESPN's position ids, resolved without a request.
///
/// The core API names a player's position by reference only —
/// `positions/30` on a game-day roster entry, `positions/8` on a depth
/// chart — and resolving each one would be a request per player per
/// roster. The id space is small and stable, so it lives here instead:
/// read off `…/leagues/{league}/positions?limit=200` on 2026-10-18, one
/// table per sport. The NFL and college football share one table
/// exactly (74 ids, identical abbreviations and names), which is why
/// `League.sportSegment` and not the league picks it.
///
/// An id that isn't here resolves to nil, and the caller falls back to
/// the team roster's own abbreviation for that athlete — a new id ESPN
/// adds degrades one player's label, never the roster.
nonisolated enum ESPNPositions {
    struct Position: Sendable, Hashable {
        let abbreviation: String
        let name: String
    }

    static func position(id: String, league: League) -> Position? {
        let table: [String: (String, String)] = switch league {
        case .collegeFootball, .nfl: football
        case .nba: basketball
        case .nhl: hockey
        }
        guard let entry = table[id] else { return nil }
        return Position(abbreviation: entry.0, name: entry.1)
    }

    /// The id at the end of a `…/positions/{id}?lang=en` ref.
    static func id(fromRef ref: String?) -> String? {
        CoreRefDTO.id(in: ref, after: "/positions/")
    }

    private static let football: [String: (String, String)] = [
        "1": ("WR", "Wide Receiver"), "2": ("LT", "Left Tackle"), "3": ("LG", "Left Guard"),
        "4": ("C", "Center"), "5": ("RG", "Right Guard"), "6": ("RT", "Right Tackle"),
        "7": ("TE", "Tight End"), "8": ("QB", "Quarterback"), "9": ("RB", "Running Back"),
        "10": ("FB", "Fullback"), "11": ("LDE", "Left Defensive End"), "12": ("NT", "Nose Tackle"),
        "13": ("RDE", "Right Defensive End"), "14": ("LOLB", "Left Outside Linebacker"),
        "15": ("LILB", "Left Inside Linebacker"), "16": ("RILB", "Right Inside Linebacker"),
        "17": ("ROLB", "Right Outside Linebacker"), "18": ("LCB", "Left Cornerback"),
        "19": ("RCB", "Right Cornerback"), "20": ("SS", "Strong Safety"), "21": ("FS", "Free Safety"),
        "22": ("PK", "Place Kicker"), "23": ("P", "Punter"), "24": ("LDT", "Left Defensive Tackle"),
        "25": ("RDT", "Right Defensive Tackle"), "26": ("WLB", "Weakside Linebacker"),
        "27": ("MLB", "Middle Linebacker"), "28": ("SLB", "Strongside Linebacker"),
        "29": ("CB", "Cornerback"), "30": ("LB", "Linebacker"), "31": ("DE", "Defensive End"),
        "32": ("DT", "Defensive Tackle"), "33": ("UT", "Under Tackle"), "34": ("NB", "Nickel Back"),
        "35": ("DB", "Defensive Back"), "36": ("S", "Safety"), "37": ("DL", "Defensive Lineman"),
        "39": ("LS", "Long Snapper"), "45": ("OL", "Offensive Lineman"), "46": ("OT", "Offensive Tackle"),
        "47": ("OG", "Offensive Guard"), "50": ("ATH", "Athlete"), "70": ("OFF", "Offense"),
        "71": ("DEF", "Defense"), "72": ("ST", "Special Teams"), "73": ("G", "Guard"),
        "74": ("T", "Tackle"), "75": ("NG", "Nose Guard"), "76": ("PR", "Punt Returner"),
        "77": ("KR", "Kick Returner"), "78": ("LS", "Long Snapper"), "79": ("H", "Holder"),
        "80": ("PK", "Place Kicker"), "90": ("ILB", "Inside Linebacker"), "91": ("C", "Center"),
        "94": ("P", "Punter"), "96": ("LS", "Long Snapper"), "100": ("FL", "Flanker"),
        "101": ("HB", "Halfback"), "102": ("TB", "Tailback"), "103": ("LHB", "Left Halfback"),
        "104": ("RHB", "Right Halfback"), "105": ("LLB", "Left Linebacker"),
        "106": ("RLB", "Right Linebacker"), "107": ("OLB", "Outside Linebacker"),
        "108": ("LSF", "Left Safety"), "109": ("RSF", "Right Safety"), "110": ("MG", "Middle Guard"),
        "111": ("SE", "Split End"), "219": ("B", "Back"), "264": ("EDGE", "EDGE"),
    ]

    private static let basketball: [String: (String, String)] = [
        "1": ("PG", "Point Guard"), "2": ("SG", "Shooting Guard"), "3": ("G", "Guard"),
        "4": ("GF", "Guard-Forward"), "5": ("SF", "Small Forward"), "6": ("PF", "Power Forward"),
        "7": ("F", "Forward"), "8": ("FC", "Forward-Center"), "9": ("C", "Center"),
    ]

    private static let hockey: [String: (String, String)] = [
        "1": ("C", "Center"), "2": ("LW", "Left Wing"), "3": ("RW", "Right Wing"),
        "4": ("D", "Defense"), "5": ("G", "Goaltender"), "8": ("W", "Winger"),
        "9": ("EX", "Extra Attacker"), "13": ("LD", "Left Defense"), "14": ("RD", "Right Defense"),
        "20": ("F", "Forward"), "27": ("S", "Skater"),
    ]
}
