//
//  Formatters.swift
//  Lactate test app_v3
//

import Foundation

enum UnitPreference: String, CaseIterable, Identifiable {
    case metric
    case imperial

    var id: String { rawValue }
}

struct PaceFormatter {
    static func string(fromSecondsPerKm seconds: Int, unit: UnitPreference) -> String {
        let totalSeconds: Int
        if unit == .metric {
            totalSeconds = seconds
        } else {
            totalSeconds = Int(Double(seconds) * 1.609344)
        }

        let min = totalSeconds / 60
        let sec = totalSeconds % 60
        let suffix = (unit == .metric) ? "km" : "mi"
        return String(format: "%d:%02d min/%@", min, sec, suffix)
    }
}

struct SpeedFormatter {
    static func string(fromKmh kmh: Double, unit: UnitPreference) -> String {
        let speed: Double
        let unitString: String

        if unit == .metric {
            speed = kmh
            unitString = "km/h"
        } else {
            speed = kmh / 1.609344
            unitString = "mph"
        }

        return String(format: "%.1f %@", speed, unitString)
    }
}
