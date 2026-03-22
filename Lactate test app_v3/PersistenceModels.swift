//
//  PersistenceModels.swift
//  Lactate test app_v3
//
//  Created by Bruno Oliveira on 3/15/26.
//

import Foundation
import SwiftData

@Model
final class AthleteEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var dateOfBirth: Date?
    var genderRawValue: String?
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \LactateTestEntity.athlete)
    var tests: [LactateTestEntity]

    init(
        id: UUID = UUID(),
        name: String,
        dateOfBirth: Date? = nil,
        genderRawValue: String? = nil,
        createdAt: Date = Date(),
        tests: [LactateTestEntity] = []
    ) {
        self.id = id
        self.name = name
        self.dateOfBirth = dateOfBirth
        self.genderRawValue = genderRawValue
        self.createdAt = createdAt
        self.tests = tests
    }

    var gender: AthleteGender? {
        get {
            guard let genderRawValue else { return nil }
            return AthleteGender(rawValue: genderRawValue)
        }
        set {
            genderRawValue = newValue?.rawValue
        }
    }
}

@Model
final class LactateTestEntity {
    @Attribute(.unique) var id: UUID
    var athleteName: String
    var testName: String?
    var restingLactate: Double?
    var bodyMassKg: Double?
    var temperatureCelsius: Double?
    var temperatureUnitRawValue: String?
    var humidityPercent: Double?
    var terrain: String?
    var notes: String?
    var sportRawValue: String
    var date: Date

    var athlete: AthleteEntity?

    @Relationship(deleteRule: .cascade, inverse: \LactateStepEntity.test)
    var steps: [LactateStepEntity]

    init(
        id: UUID = UUID(),
        athleteName: String,
        testName: String? = nil,
        restingLactate: Double? = nil,
        bodyMassKg: Double? = nil,
        temperatureCelsius: Double? = nil,
        temperatureUnitRawValue: String? = TemperatureUnit.celsius.rawValue,
        humidityPercent: Double? = nil,
        terrain: String? = nil,
        notes: String? = nil,
        sportRawValue: String,
        date: Date,
        athlete: AthleteEntity? = nil,
        steps: [LactateStepEntity] = []
    ) {
        self.id = id
        self.athleteName = athleteName
        self.testName = testName
        self.restingLactate = restingLactate
        self.bodyMassKg = bodyMassKg
        self.temperatureCelsius = temperatureCelsius
        self.temperatureUnitRawValue = temperatureUnitRawValue
        self.humidityPercent = humidityPercent
        self.terrain = terrain
        self.notes = notes
        self.sportRawValue = sportRawValue
        self.date = date
        self.athlete = athlete
        self.steps = steps
    }

    var sport: Sport {
        get { Sport(rawValue: sportRawValue) ?? .running }
        set { sportRawValue = newValue.rawValue }
    }

    var temperatureUnit: TemperatureUnit {
        get { TemperatureUnit(rawValue: temperatureUnitRawValue ?? TemperatureUnit.celsius.rawValue) ?? .celsius }
        set { temperatureUnitRawValue = newValue.rawValue }
    }
}

@Model
final class LactateStepEntity {
    @Attribute(.unique) var id: UUID
    var stepIndex: Int
    var lactate: Double?
    var avgHeartRate: Int?
    var runningPaceSecondsPerKm: Int?
    var cyclingSpeedKmh: Double?
    var powerWatts: Int?

    var test: LactateTestEntity?

    init(
        id: UUID = UUID(),
        stepIndex: Int,
        lactate: Double? = nil,
        avgHeartRate: Int? = nil,
        runningPaceSecondsPerKm: Int? = nil,
        cyclingSpeedKmh: Double? = nil,
        powerWatts: Int? = nil,
        test: LactateTestEntity? = nil
    ) {
        self.id = id
        self.stepIndex = stepIndex
        self.lactate = lactate
        self.avgHeartRate = avgHeartRate
        self.runningPaceSecondsPerKm = runningPaceSecondsPerKm
        self.cyclingSpeedKmh = cyclingSpeedKmh
        self.powerWatts = powerWatts
        self.test = test
    }
}


