import SwiftUI

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


