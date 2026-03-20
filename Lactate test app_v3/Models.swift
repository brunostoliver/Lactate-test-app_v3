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

struct Athlete: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
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
    var athleteID: UUID?
    var athleteName: String
    var testName: String?
    var sport: Sport
    var date: Date
    var steps: [LactateStep]

    init(
        id: UUID = UUID(),
        athleteID: UUID? = nil,
        athleteName: String,
        testName: String? = nil,
        sport: Sport,
        date: Date,
        steps: [LactateStep]
    ) {
        self.id = id
        self.athleteID = athleteID
        self.athleteName = athleteName
        self.testName = testName
        self.sport = sport
        self.date = date
        self.steps = steps
    }

    var resolvedTestName: String {
        Self.normalizedTestName(testName, sport: sport, date: date)
    }

    static func normalizedTestName(_ rawName: String?, sport: Sport, date: Date) -> String {
        let trimmed = rawName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty {
            return trimmed
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "\(sport.rawValue.capitalized) - \(formatter.string(from: date))"
    }
}

struct LactateTestDraft {
    var athleteID: UUID?
    var athleteName: String
    var testName: String
    var sport: Sport
    var date: Date
    var steps: [LactateStep]

    init(
        athleteID: UUID? = nil,
        athleteName: String = "",
        testName: String = "",
        sport: Sport = .running,
        date: Date = Date(),
        steps: [LactateStep] = [LactateStep.emptyStep(stepIndex: 1)]
    ) {
        self.athleteID = athleteID
        self.athleteName = athleteName
        self.testName = testName
        self.sport = sport
        self.date = date
        self.steps = steps
    }

    var resolvedTestName: String {
        LactateTest.normalizedTestName(testName, sport: sport, date: date)
    }

    func asLactateTest() -> LactateTest {
        LactateTest(
            athleteID: athleteID,
            athleteName: athleteName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Athlete" : athleteName,
            testName: LactateTest.normalizedTestName(testName, sport: sport, date: date),
            sport: sport,
            date: date,
            steps: steps
        )
    }

    mutating func reset() {
        self = LactateTestDraft()
    }
}

