import SwiftUI

extension ContentView {
    // MARK: - Formatting

    func formatXAxisValue(_ value: Double) -> String {
        switch graphXAxis {
        case .power:
            return "\(Int(value.rounded())) W"
        case .heartRate:
            return "\(Int(value.rounded())) bpm"
        }
    }

    func formatExportXAxisValue(_ value: Double) -> String {
        "\(Int(value.rounded())) W"
    }

    func formatHeartRate(_ value: Double) -> String {
        "\(Int(value.rounded())) bpm"
    }

    func formatPower(_ value: Double) -> String {
        "\(Int(value.rounded())) W"
    }

    func formatSpeed(_ value: Double) -> String {
        SpeedFormatter.string(fromKmh: value, unit: unitPreference)
    }

    func formatPace(_ value: Double) -> String {
        PaceFormatter.string(fromSecondsPerKm: Int(value.rounded()), unit: unitPreference)
    }

    func formatPrimaryWorkload(_ value: Double) -> String {
        switch draft.sport {
        case .cycling:
            if draft.steps.contains(where: { $0.powerWatts != nil && $0.lactate != nil }) {
                return formatPower(value)
            }
            if draft.steps.contains(where: { $0.cyclingSpeedKmh != nil && $0.lactate != nil }) {
                return formatSpeed(value)
            }
            return formatHeartRate(value)

        case .running:
            if draft.steps.contains(where: { $0.runningPaceSecondsPerKm != nil && $0.lactate != nil }) {
                return formatSpeed(value)
            }
            if draft.steps.contains(where: { $0.powerWatts != nil && $0.lactate != nil }) {
                return formatPower(value)
            }
            return formatHeartRate(value)
        }
    }

    func formatPrimaryWorkload(_ value: Double, for test: LactateTest) -> String {
        switch test.sport {
        case .cycling:
            if test.steps.contains(where: { $0.powerWatts != nil && $0.lactate != nil }) {
                return formatPower(value)
            }
            if test.steps.contains(where: { $0.cyclingSpeedKmh != nil && $0.lactate != nil }) {
                return formatSpeed(value)
            }
            return formatHeartRate(value)

        case .running:
            if test.steps.contains(where: { $0.runningPaceSecondsPerKm != nil && $0.lactate != nil }) {
                return formatSpeed(value)
            }
            if test.steps.contains(where: { $0.powerWatts != nil && $0.lactate != nil }) {
                return formatPower(value)
            }
            return formatHeartRate(value)
        }
    }

    func shortDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    func testLabel(for test: LactateTest) -> String {
        test.resolvedTestName
    }

}


