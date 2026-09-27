import Foundation

/// ESPN's story HTML, turned into headings and paragraphs the reader can
/// set in the app's own type (N4).
///
/// Two dialects arrive. AP copy inside the game summary separates
/// paragraphs with blank lines and marks its subheads `<hl2>`; ESPN's own
/// stories from the content API use `<p>` and `<h2>`, with embeds (`<img>`,
/// `<inline1>`, `<alsosee>`) between them. Both come down to the same two
/// blocks. Links keep their words and lose their targets: a story is read
/// here, and every link in one points at espn.com.
nonisolated enum StoryText {
    static func blocks(fromHTML html: String) -> [StoryBlock] {
        var text = html
        // Headings become their own lines, marked so they survive the tag
        // strip below. \u{1} can't occur in ESPN's text.
        text = replacing(#"<\s*(h[1-6]|hl[1-6])\b[^>]*>(.*?)<\s*/\s*\1\s*>"#,
                         in: text, with: "\n\n\u{1}$2\n\n")
        // Block-level tags break paragraphs.
        text = replacing(#"<\s*/?\s*(p|div|br|hr|li|ul|ol|blockquote)\b[^>]*>"#,
                         in: text, with: "\n\n")
        // Everything else goes, embeds included.
        text = replacing(#"<[^>]*>"#, in: text, with: "")

        var blocks: [StoryBlock] = []
        for raw in text.components(separatedBy: "\n\n") {
            let line = collapsingWhitespace(decodingEntities(raw))
            guard !line.isEmpty else { continue }
            // AP closes with a rule and then its boilerplate: contributor
            // notes and a link to its hub. The story is over at the rule.
            if line.allSatisfy({ $0 == "-" }) { break }
            if line.hasPrefix("\u{1}") {
                let heading = line.dropFirst().trimmingCharacters(in: .whitespaces)
                if !heading.isEmpty { blocks.append(.heading(heading)) }
            } else {
                blocks.append(.paragraph(tidyingDateline(line)))
            }
        }
        return blocks
    }

    /// AP's dateline arrives as "NEW YORK -- — Karl-Anthony Towns…": the
    /// wire's double hyphen and ESPN's dash, both. One dash is the dateline.
    private static func tidyingDateline(_ line: String) -> String {
        line.replacingOccurrences(of: " -- — ", with: " — ")
    }

    private static func collapsingWhitespace(_ string: String) -> String {
        string.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static let namedEntities: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ",
        "rsquo": "’", "lsquo": "‘", "rdquo": "”", "ldquo": "“",
        "mdash": "—", "ndash": "–", "hellip": "…",
    ]

    static func decodingEntities(_ string: String) -> String {
        guard string.contains("&") else { return string }
        var result = ""
        var rest = Substring(string)
        while let amp = rest.firstIndex(of: "&") {
            result += rest[..<amp]
            let after = rest[rest.index(after: amp)...]
            if let semi = after.prefix(10).firstIndex(of: ";") {
                let name = after[..<semi]
                if let decoded = decodeEntity(String(name)) {
                    result += decoded
                    rest = after[after.index(after: semi)...]
                    continue
                }
            }
            result += "&"
            rest = after
        }
        return result + rest
    }

    private static func decodeEntity(_ name: String) -> String? {
        if let named = namedEntities[name] { return named }
        guard name.hasPrefix("#") else { return nil }
        let digits = name.dropFirst()
        let value = digits.first == "x" || digits.first == "X"
            ? UInt32(digits.dropFirst(), radix: 16)
            : UInt32(digits, radix: 10)
        return value.flatMap(Unicode.Scalar.init).map { String(Character($0)) }
    }

    private static func replacing(_ pattern: String, in string: String, with template: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return string }
        return regex.stringByReplacingMatches(
            in: string, range: NSRange(string.startIndex..., in: string), withTemplate: template)
    }
}
