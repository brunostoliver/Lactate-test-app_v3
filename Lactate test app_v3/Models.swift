//
//  Models.swift
//  Lactate test app_v3
//

import Foundation
import Combine

enum Sport: String, CaseIterable, Identifiable {
    case running
    case cycling

    var id: String { rawValue }
}

struct LactateStep: Identifiable, Hashable {
    var id = UUID()
    var stepIndex: Int
    var lactate: Double?
    var avgHeartRate: Int?
    var runningPaceSecondsPerKm: Int?
    var cyclingSpeedKmh: Double?
    var powerWatts: Int?
}

struct LactateTest: Identifiable, Hashable {
    var id = UUID()
    var athleteName: String
    var sport: Sport
    var date: Date
    var steps: [LactateStep]
}

final class TestsStore: ObservableObject {
    @Published var tests: [LactateTest] = []
}
