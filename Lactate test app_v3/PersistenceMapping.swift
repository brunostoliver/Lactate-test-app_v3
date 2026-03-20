//
//  PersistenceMapping.swift
//  Lactate test app_v3
//
//  Created by Bruno Oliveira on 3/15/26.
//

import Foundation
import SwiftData

extension Athlete {
    init(entity: AthleteEntity) {
        self.init(
            id: entity.id,
            name: entity.name,
            createdAt: entity.createdAt
        )
    }

    func makeEntity() -> AthleteEntity {
        AthleteEntity(
            id: id,
            name: name,
            createdAt: createdAt
        )
    }
}

extension LactateStep {
    init(entity: LactateStepEntity) {
        self.init(
            id: entity.id,
            stepIndex: entity.stepIndex,
            lactate: entity.lactate,
            avgHeartRate: entity.avgHeartRate,
            runningPaceSecondsPerKm: entity.runningPaceSecondsPerKm,
            cyclingSpeedKmh: entity.cyclingSpeedKmh,
            powerWatts: entity.powerWatts
        )
    }

    func makeEntity() -> LactateStepEntity {
        LactateStepEntity(
            id: id,
            stepIndex: stepIndex,
            lactate: lactate,
            avgHeartRate: avgHeartRate,
            runningPaceSecondsPerKm: runningPaceSecondsPerKm,
            cyclingSpeedKmh: cyclingSpeedKmh,
            powerWatts: powerWatts
        )
    }
}

extension LactateTest {
    init(entity: LactateTestEntity) {
        let mappedSteps = entity.steps
            .sorted { $0.stepIndex < $1.stepIndex }
            .map { LactateStep(entity: $0) }

        self.init(
            id: entity.id,
            athleteID: entity.athlete?.id,
            athleteName: entity.athleteName,
            testName: entity.testName,
            temperatureCelsius: entity.temperatureCelsius,
            temperatureUnit: entity.temperatureUnit,
            humidityPercent: entity.humidityPercent,
            terrain: entity.terrain,
            sport: entity.sport,
            date: entity.date,
            steps: mappedSteps
        )
    }

    func makeEntity() -> LactateTestEntity {
        let entity = LactateTestEntity(
            id: id,
            athleteName: athleteName,
            testName: testName,
            temperatureCelsius: temperatureCelsius,
            temperatureUnitRawValue: temperatureUnit.rawValue,
            humidityPercent: humidityPercent,
            terrain: terrain,
            sportRawValue: sport.rawValue,
            date: date
        )

        let mappedSteps = steps
            .sorted { $0.stepIndex < $1.stepIndex }
            .map { step -> LactateStepEntity in
                let stepEntity = step.makeEntity()
                stepEntity.test = entity
                return stepEntity
            }

        entity.steps = mappedSteps
        return entity
    }
}


