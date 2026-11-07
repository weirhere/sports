import Foundation

/// A venue as an Apple Maps search (COR-151, 2026-11-07).
///
/// ESPN gives a ground's name and city and no coordinates or address, so
/// the link is a `q=` search: "Benchmark International Arena, Tampa, FL".
/// `https://maps.apple.com` rather than `maps://` because it opens Maps on
/// iOS and still lands somewhere useful anywhere else.
nonisolated enum MapsLink {
    /// Nil when there is no name to search for.
    static func url(name: String, city: String?) -> URL? {
        let place = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !place.isEmpty else { return nil }
        let town = city?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let parts = town.isEmpty ? [place] : [place, town]
        // `URLComponents` leaves `&`, `=` and `+` alone inside a query
        // value, so "AT&T Stadium" would search for "AT". Encode by hand.
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+?#")
        guard let query = parts.joined(separator: ", ")
            .addingPercentEncoding(withAllowedCharacters: allowed)
        else { return nil }
        return URL(string: "https://maps.apple.com/?q=\(query)")
    }
}
