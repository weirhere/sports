import Foundation

/// The quarter marker the scoring list and the drive log both print above
/// a run of rows. One copy — the two lists carried it verbatim.
enum PeriodLabel {
    static func text(_ period: Int?) -> String {
        guard let period else { return "—" }
        switch period {
        case 1: return "1ST QUARTER"
        case 2: return "2ND QUARTER"
        case 3: return "3RD QUARTER"
        case 4: return "4TH QUARTER"
        case 5: return "OVERTIME"
        default: return "\(period - 4)OT"
        }
    }
}
