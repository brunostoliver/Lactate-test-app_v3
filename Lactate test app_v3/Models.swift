//
//  Models.swift
//  Lactate test app_v3
//
//  Created by Bruno Oliveira on 3/15/26.
//

import Foundation

enum Sport: String, CaseIterable, Identifiable, Codable {
    case running
    case cycling

    var id: String { rawValue }
}

struct LactateStep: Identifiable, Codable, Hashable {
    let id: UUID
    var stepIndex: Int
    var lactate: Double?
    var avgHeartRate: Int?
    var runningPaceSecondsPerKm: Int?
    var cyclingSpeedKmh: Double?
    var powerWatts: Int?

    init(
        id: UUID = UUID(),
        stepIndex: Int,
        lactate: Double?,
        avgHeartRate: Int?,
        runningPaceSecondsPerKm: Int?,
        cyclingSpeedKmh: Double?,
        powerWatts: Int?
    ) {
        self.id = id
        self.stepIndex = stepIndex
        self.lactate = lactate
        self.avgHeartRate = avgHeartRate
        self.runningPaceSecondsPerKm = runningPaceSecondsPerKm
        self.cyclingSpeedKmh = cyclingSpeedKmh
        self.powerWatts = powerWatts
    }

    static func emptyStep(stepIndex: Int = 1) -> LactateStep {
        LactateStep(
            stepIndex: stepIndex,
            lactate: nil,
            avgHeartRate: nil,
            runningPaceSecondsPerKm: nil,
            cyclingSpeedKmh: nil,
            powerWatts: nil
        )
    }
}

struct LactateTest: Identifiable, Codable, Hashable {
    let id: UUID
    var athleteName: String
    var sport: Sport
    var date: Date
    var steps: [LactateStep]

    init(
        id: UUID = UUID(),
        athleteName: String,
        sport: Sport,
        date: Date,
        steps: [LactateStep]
    ) {
        self.id = id
        self.athleteName = athleteName
        self.sport = sport
        self.date = date
        self.steps = steps
    }
}

struct LactateTestDraft {
    var athleteName: String
    var sport: Sport
    var date: Date
    var steps: [LactateStep]

    init(
        athleteName: String = "",
        sport: Sport = .running,
        date: Date = Date(),
        steps: [LactateStep] = [LactateStep.emptyStep(stepIndex: 1)]
    ) {
        self.athleteName = athleteName
        self.sport = sport
        self.date = date
        self.steps = steps
    }

    func asLactateTest() -> LactateTest {
        LactateTest(
            athleteName: athleteName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Test" : athleteName,
            sport: sport,
            date: date,
            steps: steps
        )
    }

    mutating func reset() {
        self = LactateTestDraft()
    }
}
