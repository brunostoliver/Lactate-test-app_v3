import SwiftUI

enum ThresholdInfoTopic: String, Identifiable {
    case lt1
    case dmax
    case modifiedDmax
    case logLog
    case lt2
    case vo2Max
    case ftp
    case raceTimes
    case vo2Percentile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lt1:
            return "LT1"
        case .dmax:
            return "Dmax"
        case .modifiedDmax:
            return "Modified Dmax"
        case .logLog:
            return "Log-Log Breakpoint"
        case .lt2:
            return "LT2"
        case .vo2Max:
            return "Estimated VO2max"
        case .ftp:
            return "Estimated FTP"
        case .raceTimes:
            return "Estimated Race Times"
        case .vo2Percentile:
            return "Percentile"
        }
    }

    var defaultMessage: String {
        switch self {
        case .lt1:
            return "First lactate turnpoint, commonly estimated near 2.0 mmol/L."
        case .dmax:
            return "Point farthest from the baseline between first and last steps."
        case .modifiedDmax:
            return "Newell-style Dmax variant using a reduced, more stable curve range."
        case .logLog:
            return "Breakpoint from log-transformed workload and lactate curve relationships.\n\nIt may be unavailable if there are too few valid steps, missing values, or no clear breakpoint in the curve."
        case .lt2:
            return "Second lactate turnpoint, commonly estimated near 4.0 mmol/L."
        case .vo2Max:
            return "Estimated from LT2. Running uses flat pace cost; cycling uses power, weight, and LT2."
        case .ftp:
            return "Cycling-only estimate using LT2 power. Relative FTP uses test-day body mass."
        case .raceTimes:
            return "Running-only prediction from estimated VO2max. Weather, terrain, pacing, and durability can change outcomes."
        case .vo2Percentile:
            return "Percentile shows how your estimated VO2max compares with people of the same age and gender.\n\n50th = average\n80th = better than about 80% of peers\n90th = better than about 90% of peers\n\nThis is an estimate based on reference norms."
        }
    }
}

enum GraphXAxis: String, CaseIterable, Identifiable {
    case power
    case heartRate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .power:
            return "Power"
        case .heartRate:
            return "Heart Rate"
        }
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

enum TestSportFilter: String, CaseIterable, Identifiable {
    case all
    case running
    case cycling

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .running:
            return "Running"
        case .cycling:
            return "Cycling"
        }
    }

    var sport: Sport? {
        switch self {
        case .all:
            return nil
        case .running:
            return .running
        case .cycling:
            return .cycling
        }
    }
}

enum ExportError: LocalizedError {
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "The export file could not be encoded."
        }
    }
}

struct ExportAnalysisSummary {
    let thresholdLines: [String]
    let zoneLines: [String]
}

struct GraphPoint: Identifiable {
    let id = UUID()
    let stepIndex: Int
    let x: Double
    let lactate: Double
    let heartRate: Int?
    let power: Int?
    let seriesLabel: String
    let seriesColor: Color
}

struct GraphSeries: Identifiable {
    let id: String
    let label: String
    let color: Color
    let points: [GraphPoint]
}

struct ThresholdPoint {
    let x: Double
    let lactate: Double
}

struct WorkloadLactatePoint {
    let workload: Double
    let lactate: Double
}

struct MetricLactatePair {
    let metric: Double
    let lactate: Double
}

struct WorkloadThresholdResult {
    let workload: Double
    let lactate: Double
}

struct VO2MaxEstimate {
    let value: Double
    let methodSummary: String
}

struct FTPEstimate {
    let watts: Double
    let wattsPerKg: Double?
}

struct RaceTimePrediction: Identifiable {
    let id: String
    let title: String
    let distanceMeters: Double
    let timeMinutes: Double
}

let runningRacePredictionVDOTFactor = 0.96

enum VO2ClassificationLabel: String {
    case poor = "Poor"
    case fair = "Fair"
    case average = "Average"
    case good = "Good"
    case excellent = "Excellent"
    case superior = "Superior"
}

struct VO2PercentileBand {
    let percentile: Int
    let value: Double
}

struct VO2NormTable {
    let ageRange: ClosedRange<Int>
    let maleBands: [VO2PercentileBand]
    let femaleBands: [VO2PercentileBand]
}

struct VO2ClassificationResult {
    let percentile: Int
    let classification: VO2ClassificationLabel
}

let vo2NormTables: [VO2NormTable] = [
    VO2NormTable(
        ageRange: 20...29,
        maleBands: [.init(percentile: 10, value: 35.2), .init(percentile: 20, value: 39.5), .init(percentile: 30, value: 40.3), .init(percentile: 40, value: 42.2), .init(percentile: 50, value: 43.9), .init(percentile: 60, value: 45.7), .init(percentile: 70, value: 48.2), .init(percentile: 80, value: 51.1), .init(percentile: 90, value: 54.0)],
        femaleBands: [.init(percentile: 10, value: 29.4), .init(percentile: 20, value: 31.6), .init(percentile: 30, value: 33.8), .init(percentile: 40, value: 35.5), .init(percentile: 50, value: 37.4), .init(percentile: 60, value: 39.5), .init(percentile: 70, value: 41.1), .init(percentile: 80, value: 44.0), .init(percentile: 90, value: 47.5)]
    ),
    VO2NormTable(
        ageRange: 30...39,
        maleBands: [.init(percentile: 10, value: 33.8), .init(percentile: 20, value: 36.7), .init(percentile: 30, value: 38.5), .init(percentile: 40, value: 41.0), .init(percentile: 50, value: 42.4), .init(percentile: 60, value: 44.4), .init(percentile: 70, value: 46.8), .init(percentile: 80, value: 48.9), .init(percentile: 90, value: 52.5)],
        femaleBands: [.init(percentile: 10, value: 27.4), .init(percentile: 20, value: 29.9), .init(percentile: 30, value: 32.3), .init(percentile: 40, value: 33.8), .init(percentile: 50, value: 35.2), .init(percentile: 60, value: 36.7), .init(percentile: 70, value: 38.8), .init(percentile: 80, value: 41.0), .init(percentile: 90, value: 44.7)]
    ),
    VO2NormTable(
        ageRange: 40...49,
        maleBands: [.init(percentile: 10, value: 31.8), .init(percentile: 20, value: 34.6), .init(percentile: 30, value: 36.7), .init(percentile: 40, value: 38.4), .init(percentile: 50, value: 40.4), .init(percentile: 60, value: 42.4), .init(percentile: 70, value: 44.2), .init(percentile: 80, value: 46.8), .init(percentile: 90, value: 51.1)],
        femaleBands: [.init(percentile: 10, value: 25.6), .init(percentile: 20, value: 28.0), .init(percentile: 30, value: 29.7), .init(percentile: 40, value: 31.6), .init(percentile: 50, value: 33.3), .init(percentile: 60, value: 35.1), .init(percentile: 70, value: 36.7), .init(percentile: 80, value: 38.9), .init(percentile: 90, value: 42.4)]
    ),
    VO2NormTable(
        ageRange: 50...59,
        maleBands: [.init(percentile: 10, value: 28.4), .init(percentile: 20, value: 31.1), .init(percentile: 30, value: 33.2), .init(percentile: 40, value: 35.2), .init(percentile: 50, value: 36.7), .init(percentile: 60, value: 38.3), .init(percentile: 70, value: 41.0), .init(percentile: 80, value: 43.3), .init(percentile: 90, value: 46.8)],
        femaleBands: [.init(percentile: 10, value: 23.7), .init(percentile: 20, value: 25.5), .init(percentile: 30, value: 27.3), .init(percentile: 40, value: 28.7), .init(percentile: 50, value: 30.2), .init(percentile: 60, value: 31.4), .init(percentile: 70, value: 32.9), .init(percentile: 80, value: 35.2), .init(percentile: 90, value: 38.1)]
    ),
    VO2NormTable(
        ageRange: 60...69,
        maleBands: [.init(percentile: 10, value: 24.1), .init(percentile: 20, value: 27.4), .init(percentile: 30, value: 29.4), .init(percentile: 40, value: 31.4), .init(percentile: 50, value: 33.1), .init(percentile: 60, value: 35.0), .init(percentile: 70, value: 36.7), .init(percentile: 80, value: 39.5), .init(percentile: 90, value: 43.2)],
        femaleBands: [.init(percentile: 10, value: 21.7), .init(percentile: 20, value: 23.7), .init(percentile: 30, value: 24.9), .init(percentile: 40, value: 26.6), .init(percentile: 50, value: 27.5), .init(percentile: 60, value: 29.1), .init(percentile: 70, value: 30.2), .init(percentile: 80, value: 32.3), .init(percentile: 90, value: 34.6)]
    )
]

struct LinearRegressionResult {
    let intercept: Double
    let slope: Double
    let sse: Double
}

struct FiveZoneThresholds {
    let z1Upper: Double
    let z2Upper: Double
    let z3Upper: Double
    let z4Upper: Double
}

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}


