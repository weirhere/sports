import Foundation

/// Why a widget fetch came back empty-handed, as one greppable word
/// (COR-13, 2026-11-07).
///
/// The widget is the app's only unattended request surface: ~48 fetches on
/// a full Saturday with nobody watching. Its provider used to `try?` the
/// scoreboard, which kept the card alive and threw away the reason, so a
/// field Saturday's log archive could never say whether ESPN ever refused
/// it. This names the reason without growing any chrome on the card.
///
/// `label` is what lands in the log after `widget fetch: failed`, so the
/// categories are deliberately coarse: what you'd act on, not every code.
nonisolated enum WidgetFetchFailure: Equatable, Sendable {
    /// No route at all: airplane mode, no signal, DNS gone.
    case offline
    case timedOut
    /// ESPN's 429. Never observed (ESPNError.rateLimited's note), which is
    /// exactly why it gets its own word.
    case rateLimited
    /// Any other non-2xx, with its status.
    case http(Int)
    /// A 200 whose body didn't decode: ESPN changed a shape.
    case decode
    /// WidgetKit tore the task down mid-flight.
    case cancelled
    case other

    init(_ error: any Error) {
        switch error {
        case is CancellationError:
            self = .cancelled
        case ESPNError.rateLimited(retryAfter: _):
            self = .rateLimited
        case ESPNError.badStatus(let status), CFBDError.badStatus(let status):
            self = status == 429 ? .rateLimited : .http(status)
        case is DecodingError:
            self = .decode
        case let url as URLError:
            switch url.code {
            case .cancelled: self = .cancelled
            case .timedOut: self = .timedOut
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed,
                 .internationalRoamingOff, .cannotFindHost, .cannotConnectToHost,
                 .dnsLookupFailed:
                self = .offline
            default: self = .other
            }
        default:
            self = .other
        }
    }

    var label: String {
        switch self {
        case .offline: "offline"
        case .timedOut: "timeout"
        case .rateLimited: "rate-limited"
        case .http(let status): "http-\(status)"
        case .decode: "decode"
        case .cancelled: "cancelled"
        case .other: "other"
        }
    }
}
