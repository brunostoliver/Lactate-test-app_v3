import Foundation

extension DateFormatter {
    static var pdfTimestamp: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
}

