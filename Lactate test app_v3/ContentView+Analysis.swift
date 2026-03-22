import SwiftUI

extension ContentView {

    var athleteAge: Int? {
        guard let dateOfBirth = currentSelectedAthlete?.dateOfBirth else { return nil }
        return Calendar.current.dateComponents([.year], from: dateOfBirth, to: draft.date).year
    }

    var activeVO2NormTable: VO2NormTable? {
        guard let age = athleteAge else { return nil }
        return vo2NormTables.first(where: { $0.ageRange.contains(age) })
    }

    func vo2Bands(for gender: AthleteGender, table: VO2NormTable) -> [VO2PercentileBand] {
        switch gender {
        case .male:
            return table.maleBands
        case .female:
            return table.femaleBands
        }
    }

    func vo2Classification(for vo2Max: Double, age: Int, gender: AthleteGender) -> VO2ClassificationResult? {
        guard let table = vo2NormTables.first(where: { $0.ageRange.contains(age) }) else { return nil }
        let bands = vo2Bands(for: gender, table: table)
        guard let firstBand = bands.first, let lastBand = bands.last else { return nil }

        let percentile: Int
        if vo2Max <= firstBand.value {
            percentile = 10
        } else if vo2Max >= lastBand.value {
            percentile = 90
        } else {
            var computedPercentile = 10
            for index in 0..<(bands.count - 1) {
                let lower = bands[index]
                let upper = bands[index + 1]
                if vo2Max >= lower.value && vo2Max <= upper.value {
                    let fraction = (vo2Max - lower.value) / (upper.value - lower.value)
                    computedPercentile = Int((Double(lower.percentile) + fraction * Double(upper.percentile - lower.percentile)).rounded())
                    break
                }
            }
            percentile = computedPercentile
        }

        let classification: VO2ClassificationLabel
        switch percentile {
        case ..<20:
            classification = .poor
        case 20..<40:
            classification = .fair
        case 40..<60:
            classification = .average
        case 60..<80:
            classification = .good
        case 80..<90:
            classification = .excellent
        default:
            classification = .superior
        }

        return VO2ClassificationResult(percentile: percentile, classification: classification)
    }

    var currentVO2Classification: VO2ClassificationResult? {
        guard let vo2Estimate = estimatedVO2Max(for: draft),
              let age = athleteAge,
              let gender = currentSelectedAthlete?.gender else {
            return nil
        }

        return vo2Classification(for: vo2Estimate.value, age: age, gender: gender)
    }

    var vo2ClassificationInfoMessage: String {
        guard let age = athleteAge,
              let gender = currentSelectedAthlete?.gender,
              let table = activeVO2NormTable else {
            return "Classification requires athlete date of birth and gender, with norms currently supported for ages 20 to 69."
        }

        let bands = vo2Bands(for: gender, table: table)
        let ranges = [
            "Poor: <\(String(format: "%.1f", bands[1].value))",
            "Fair: \(String(format: "%.1f", bands[1].value))-\(String(format: "%.1f", bands[3].value))",
            "Average: \(String(format: "%.1f", bands[3].value))-\(String(format: "%.1f", bands[5].value))",
            "Good: \(String(format: "%.1f", bands[5].value))-\(String(format: "%.1f", bands[7].value))",
            "Excellent: \(String(format: "%.1f", bands[7].value))-\(String(format: "%.1f", bands[8].value))",
            "Superior: >\(String(format: "%.1f", bands[8].value))"
        ]

        return "\(gender.title), age \(age), norms \(table.ageRange.lowerBound)-\(table.ageRange.upperBound): " + ranges.joined(separator: "; ")
    }

    func runningSpeedPairs(for draft: LactateTestDraft) -> [MetricLactatePair] {
        draft.steps.compactMap { step -> MetricLactatePair? in
            guard let paceSeconds = step.runningPaceSecondsPerKm,
                  let lactate = step.lactate,
                  paceSeconds > 0 else { return nil }
            let speedKmh = 3600.0 / Double(paceSeconds)
            return MetricLactatePair(metric: speedKmh, lactate: lactate)
        }
    }

    func cyclingPowerPairs(for draft: LactateTestDraft) -> [MetricLactatePair] {
        draft.steps.compactMap { step -> MetricLactatePair? in
            guard let power = step.powerWatts,
                  let lactate = step.lactate else { return nil }
            return MetricLactatePair(metric: Double(power), lactate: lactate)
        }
    }

    func estimatedVO2Max(for draft: LactateTestDraft) -> VO2MaxEstimate? {
        switch draft.sport {
        case .running:
            guard let lt2SpeedKmh = interpolatedMetric(atLactate: 4.0, from: runningSpeedPairs(for: draft)) else {
                return nil
            }

            let speedMetersPerMinute = lt2SpeedKmh * 1000.0 / 60.0
            let vo2AtThreshold = (0.2 * speedMetersPerMinute) + 3.5
            let estimatedValue = vo2AtThreshold / 0.87

            return VO2MaxEstimate(
                value: estimatedValue,
                methodSummary: "LT2 pace estimate"
            )

        case .cycling:
            guard let lt2PowerWatts = interpolatedMetric(atLactate: 4.0, from: cyclingPowerPairs(for: draft)),
                  let bodyMassKg = draft.bodyMassKg,
                  bodyMassKg > 0 else {
                return nil
            }

            let vo2AtThreshold = (10.8 * lt2PowerWatts / bodyMassKg) + 7.0
            let estimatedValue = vo2AtThreshold / 0.85

            return VO2MaxEstimate(
                value: estimatedValue,
                methodSummary: "LT2 power + weight estimate"
            )
        }
    }

    func estimatedFTP(for draft: LactateTestDraft) -> FTPEstimate? {
        guard draft.sport == .cycling,
              let lt2PowerWatts = interpolatedMetric(atLactate: 4.0, from: cyclingPowerPairs(for: draft)) else {
            return nil
        }

        let wattsPerKg: Double?
        if let bodyMassKg = draft.bodyMassKg, bodyMassKg > 0 {
            wattsPerKg = lt2PowerWatts / bodyMassKg
        } else {
            wattsPerKg = nil
        }

        return FTPEstimate(watts: lt2PowerWatts, wattsPerKg: wattsPerKg)
    }

    func danielsVelocityDemand(for metersPerMinute: Double) -> Double {
        -4.60 + (0.182258 * metersPerMinute) + (0.000104 * metersPerMinute * metersPerMinute)
    }

    func danielsFractionOfVO2Max(for timeMinutes: Double) -> Double {
        0.8
        + 0.1894393 * exp(-0.012778 * timeMinutes)
        + 0.2989558 * exp(-0.1932605 * timeMinutes)
    }

    func predictedRaceTimeMinutes(distanceMeters: Double, vo2Max: Double) -> Double? {
        guard vo2Max > 0 else { return nil }

        var low = 8.0
        var high = 360.0

        func modelDifference(timeMinutes: Double) -> Double {
            let velocity = distanceMeters / timeMinutes
            let demand = danielsVelocityDemand(for: velocity)
            let fraction = danielsFractionOfVO2Max(for: timeMinutes)
            return demand / fraction - vo2Max
        }

        var lowDifference = modelDifference(timeMinutes: low)
        var highDifference = modelDifference(timeMinutes: high)

        guard lowDifference >= 0 else { return nil }

        while highDifference > 0 && high < 720 {
            high *= 1.5
            highDifference = modelDifference(timeMinutes: high)
        }

        guard highDifference <= 0 else { return nil }

        for _ in 0..<80 {
            let mid = (low + high) / 2.0
            let midDifference = modelDifference(timeMinutes: mid)

            if abs(midDifference) < 0.0001 {
                return mid
            }

            if midDifference > 0 {
                low = mid
                lowDifference = midDifference
            } else {
                high = mid
            }
        }

        return (low + high) / 2.0
    }

    var estimatedRacePredictions: [RaceTimePrediction] {
        guard draft.sport == .running,
              let vo2Estimate = estimatedVO2Max(for: draft) else {
            return []
        }

        let effectiveVDOT = vo2Estimate.value * runningRacePredictionVDOTFactor

        let races: [(String, Double)] = [
            ("5K", 5_000),
            ("10K", 10_000),
            ("Half Marathon", 21_097.5),
            ("Marathon", 42_195)
        ]

        return races.compactMap { title, distance in
            guard let predictedMinutes = predictedRaceTimeMinutes(distanceMeters: distance, vo2Max: effectiveVDOT) else {
                return nil
            }

            return RaceTimePrediction(
                id: title,
                title: title,
                distanceMeters: distance,
                timeMinutes: predictedMinutes
            )
        }
    }


    func graphPoints(for testSteps: [LactateStep], seriesLabel: String, seriesColor: Color) -> [GraphPoint] {
        let raw: [GraphPoint] = testSteps.compactMap { step in
            guard let lactate = step.lactate else { return nil }

            switch graphXAxis {
            case .power:
                guard let power = step.powerWatts else { return nil }
                return GraphPoint(
                    stepIndex: step.stepIndex,
                    x: Double(power),
                    lactate: lactate,
                    heartRate: step.avgHeartRate,
                    power: power,
                    seriesLabel: seriesLabel,
                    seriesColor: seriesColor
                )

            case .heartRate:
                guard let hr = step.avgHeartRate else { return nil }
                return GraphPoint(
                    stepIndex: step.stepIndex,
                    x: Double(hr),
                    lactate: lactate,
                    heartRate: hr,
                    power: step.powerWatts,
                    seriesLabel: seriesLabel,
                    seriesColor: seriesColor
                )
            }
        }

        return raw.sorted { $0.x < $1.x }
    }

    func nearestPoint(toX xValue: Double) -> GraphPoint? {
        guard !allDisplayedGraphPoints.isEmpty else { return nil }
        return allDisplayedGraphPoints.min { abs($0.x - xValue) < abs($1.x - xValue) }
    }

    func interpolatedThresholdPoint(targetLactate: Double) -> ThresholdPoint? {
        interpolatedThresholdPoint(targetLactate: targetLactate, points: currentGraphPoints)
    }

    func interpolatedThresholdPoint(targetLactate: Double, points: [GraphPoint]) -> ThresholdPoint? {
        guard points.count >= 2 else { return nil }

        for index in 0..<(points.count - 1) {
            let p1 = points[index]
            let p2 = points[index + 1]

            let y1 = p1.lactate
            let y2 = p2.lactate

            if y1 == targetLactate {
                return ThresholdPoint(x: p1.x, lactate: targetLactate)
            }

            if y2 == targetLactate {
                return ThresholdPoint(x: p2.x, lactate: targetLactate)
            }

            let crossesUp = y1 < targetLactate && y2 > targetLactate
            let crossesDown = y1 > targetLactate && y2 < targetLactate

            if crossesUp || crossesDown {
                let fraction = (targetLactate - y1) / (y2 - y1)
                let interpolatedX = p1.x + fraction * (p2.x - p1.x)
                return ThresholdPoint(x: interpolatedX, lactate: targetLactate)
            }
        }

        return nil
    }

    func dmaxPoint(from points: [WorkloadLactatePoint]) -> WorkloadLactatePoint? {
        guard points.count >= 3 else { return nil }

        let first = points.first!
        let last = points.last!

        let x1 = first.workload
        let y1 = first.lactate
        let x2 = last.workload
        let y2 = last.lactate

        let denominator = sqrt(pow(y2 - y1, 2) + pow(x2 - x1, 2))
        guard denominator > 0 else { return nil }

        var bestPoint: WorkloadLactatePoint?
        var bestDistance: Double = -1

        for point in points.dropFirst().dropLast() {
            let x0 = point.workload
            let y0 = point.lactate

            let numerator = abs((y2 - y1) * x0 - (x2 - x1) * y0 + x2 * y1 - y2 * x1)
            let distance = numerator / denominator

            if distance > bestDistance {
                bestDistance = distance
                bestPoint = point
            }
        }

        return bestPoint
    }

    func modifiedDmaxPoint(from points: [WorkloadLactatePoint]) -> WorkloadThresholdResult? {
        guard points.count >= 3 else { return nil }
        guard let lastPoint = points.last else { return nil }

        guard let minIndex = points.enumerated().min(by: { $0.element.lactate < $1.element.lactate })?.offset else {
            return nil
        }

        let minPoint = points[minIndex]

        let x1 = minPoint.workload
        let y1 = minPoint.lactate
        let x2 = lastPoint.workload
        let y2 = lastPoint.lactate

        let denominator = sqrt(pow(y2 - y1, 2) + pow(x2 - x1, 2))
        guard denominator > 0 else { return nil }

        var bestPoint: WorkloadLactatePoint?
        var bestDistance: Double = -1

        for (index, point) in points.enumerated() {
            if index == minIndex || index == points.count - 1 {
                continue
            }

            let x0 = point.workload
            let y0 = point.lactate
            let numerator = abs((y2 - y1) * x0 - (x2 - x1) * y0 + x2 * y1 - y2 * x1)
            let distance = numerator / denominator

            if distance > bestDistance {
                bestDistance = distance
                bestPoint = point
            }
        }

        guard let bestPoint else { return nil }
        return WorkloadThresholdResult(workload: bestPoint.workload, lactate: bestPoint.lactate)
    }

    func logLogBreakpoint(from points: [WorkloadLactatePoint]) -> WorkloadThresholdResult? {
        let validPoints = points.filter { $0.workload > 0 && $0.lactate > 0 }
        guard validPoints.count >= 4 else { return nil }

        var bestIntersectionX: Double?
        var bestIntersectionY: Double?
        var bestSSE = Double.greatestFiniteMagnitude

        for split in 1..<(validPoints.count - 2) {
            let firstSegment = Array(validPoints[0...split])
            let secondSegment = Array(validPoints[(split + 1)...])

            guard firstSegment.count >= 2, secondSegment.count >= 2 else { continue }

            let firstData = firstSegment.map { (x: $0.workload, y: log($0.lactate)) }
            let secondData = secondSegment.map { (x: $0.workload, y: log($0.lactate)) }

            guard let fit1 = linearRegression(for: firstData),
                  let fit2 = linearRegression(for: secondData) else {
                continue
            }

            let slopeDifference = fit1.slope - fit2.slope
            if abs(slopeDifference) < 0.000001 {
                continue
            }

            let intersectionX = (fit2.intercept - fit1.intercept) / slopeDifference

            let firstMinX = firstSegment.first!.workload
            let secondMaxX = secondSegment.last!.workload

            if intersectionX < firstMinX || intersectionX > secondMaxX {
                continue
            }

            let combinedSSE = fit1.sse + fit2.sse
            if combinedSSE < bestSSE {
                bestSSE = combinedSSE
                bestIntersectionX = intersectionX
                bestIntersectionY = exp(fit1.intercept + fit1.slope * intersectionX)
            }
        }

        guard let bestIntersectionX, let bestIntersectionY else { return nil }
        return WorkloadThresholdResult(workload: bestIntersectionX, lactate: bestIntersectionY)
    }

    func linearRegression(for data: [(x: Double, y: Double)]) -> LinearRegressionResult? {
        guard data.count >= 2 else { return nil }

        let n = Double(data.count)
        let sumX = data.reduce(0.0) { $0 + $1.x }
        let sumY = data.reduce(0.0) { $0 + $1.y }
        let sumXX = data.reduce(0.0) { $0 + ($1.x * $1.x) }
        let sumXY = data.reduce(0.0) { $0 + ($1.x * $1.y) }

        let denominator = (n * sumXX) - (sumX * sumX)
        guard abs(denominator) > 0.000001 else { return nil }

        let slope = ((n * sumXY) - (sumX * sumY)) / denominator
        let intercept = (sumY - slope * sumX) / n

        let sse = data.reduce(0.0) { partial, point in
            let predicted = intercept + slope * point.x
            let error = point.y - predicted
            return partial + error * error
        }

        return LinearRegressionResult(intercept: intercept, slope: slope, sse: sse)
    }

    func primaryWorkloadPoints(for draft: LactateTestDraft) -> [WorkloadLactatePoint] {
        switch draft.sport {
        case .cycling:
            let powerPoints = draft.steps.compactMap { step -> WorkloadLactatePoint? in
                guard let power = step.powerWatts, let lactate = step.lactate else { return nil }
                return WorkloadLactatePoint(workload: Double(power), lactate: lactate)
            }
            .sorted { $0.workload < $1.workload }

            if powerPoints.count >= 3 { return powerPoints }

            let speedPoints = draft.steps.compactMap { step -> WorkloadLactatePoint? in
                guard let speed = step.cyclingSpeedKmh, let lactate = step.lactate else { return nil }
                return WorkloadLactatePoint(workload: speed, lactate: lactate)
            }
            .sorted { $0.workload < $1.workload }

            if speedPoints.count >= 3 { return speedPoints }

            return draft.steps.compactMap { step -> WorkloadLactatePoint? in
                guard let hr = step.avgHeartRate, let lactate = step.lactate else { return nil }
                return WorkloadLactatePoint(workload: Double(hr), lactate: lactate)
            }
            .sorted { $0.workload < $1.workload }

        case .running:
            let paceSpeedPoints = draft.steps.compactMap { step -> WorkloadLactatePoint? in
                guard let paceSeconds = step.runningPaceSecondsPerKm,
                      let lactate = step.lactate,
                      paceSeconds > 0 else { return nil }
                let speedKmh = 3600.0 / Double(paceSeconds)
                return WorkloadLactatePoint(workload: speedKmh, lactate: lactate)
            }
            .sorted { $0.workload < $1.workload }

            if paceSpeedPoints.count >= 3 { return paceSpeedPoints }

            let powerPoints = draft.steps.compactMap { step -> WorkloadLactatePoint? in
                guard let power = step.powerWatts, let lactate = step.lactate else { return nil }
                return WorkloadLactatePoint(workload: Double(power), lactate: lactate)
            }
            .sorted { $0.workload < $1.workload }

            if powerPoints.count >= 3 { return powerPoints }

            return draft.steps.compactMap { step -> WorkloadLactatePoint? in
                guard let hr = step.avgHeartRate, let lactate = step.lactate else { return nil }
                return WorkloadLactatePoint(workload: Double(hr), lactate: lactate)
            }
            .sorted { $0.workload < $1.workload }
        }
    }

    func fiveZonesIncreasing(from pairs: [MetricLactatePair], middleLactate: Double?) -> FiveZoneThresholds? {
        guard let middleLactate else { return nil }

        guard let lt1 = interpolatedMetric(atLactate: 2.0, from: pairs),
              let middle = interpolatedMetric(atLactate: middleLactate, from: pairs),
              let lt2 = interpolatedMetric(atLactate: 4.0, from: pairs) else {
            return nil
        }

        return FiveZoneThresholds(
            z1Upper: lt1 * 0.90,
            z2Upper: lt1,
            z3Upper: middle,
            z4Upper: lt2
        )
    }

    func interpolatedMetric(atLactate targetLactate: Double, from pairs: [MetricLactatePair]) -> Double? {
        guard pairs.count >= 2 else { return nil }

        let sortedPairs = pairs.sorted { $0.metric < $1.metric }

        for index in 0..<(sortedPairs.count - 1) {
            let p1 = sortedPairs[index]
            let p2 = sortedPairs[index + 1]

            let y1 = p1.lactate
            let y2 = p2.lactate

            if y1 == targetLactate { return p1.metric }
            if y2 == targetLactate { return p2.metric }

            let crossesUp = y1 < targetLactate && y2 > targetLactate
            let crossesDown = y1 > targetLactate && y2 < targetLactate

            if crossesUp || crossesDown {
                let fraction = (targetLactate - y1) / (y2 - y1)
                return p1.metric + fraction * (p2.metric - p1.metric)
            }
        }

        return nil
    }

    func heartRateFiveZones(for draft: LactateTestDraft) -> FiveZoneThresholds? {
        let pairs = draft.steps.compactMap { step -> MetricLactatePair? in
            guard let hr = step.avgHeartRate, let lactate = step.lactate else { return nil }
            return MetricLactatePair(metric: Double(hr), lactate: lactate)
        }
        return fiveZonesIncreasing(from: pairs, middleLactate: preferredMiddleLactate)
    }

    func powerFiveZones(for draft: LactateTestDraft) -> FiveZoneThresholds? {
        let pairs = draft.steps.compactMap { step -> MetricLactatePair? in
            guard let power = step.powerWatts, let lactate = step.lactate else { return nil }
            return MetricLactatePair(metric: Double(power), lactate: lactate)
        }
        return fiveZonesIncreasing(from: pairs, middleLactate: preferredMiddleLactate)
    }

    func cyclingSpeedFiveZones(for draft: LactateTestDraft) -> FiveZoneThresholds? {
        let pairs = draft.steps.compactMap { step -> MetricLactatePair? in
            guard let speed = step.cyclingSpeedKmh, let lactate = step.lactate else { return nil }
            return MetricLactatePair(metric: speed, lactate: lactate)
        }
        return fiveZonesIncreasing(from: pairs, middleLactate: preferredMiddleLactate)
    }

    func runningPaceFiveZones(for draft: LactateTestDraft) -> FiveZoneThresholds? {
        let pairs = draft.steps.compactMap { step -> MetricLactatePair? in
            guard let paceSeconds = step.runningPaceSecondsPerKm,
                  let lactate = step.lactate,
                  paceSeconds > 0 else { return nil }
            let speedKmh = 3600.0 / Double(paceSeconds)
            return MetricLactatePair(metric: speedKmh, lactate: lactate)
        }

        guard let speedZones = fiveZonesIncreasing(from: pairs, middleLactate: preferredMiddleLactate) else {
            return nil
        }

        return FiveZoneThresholds(
            z1Upper: 3600.0 / speedZones.z1Upper,
            z2Upper: 3600.0 / speedZones.z2Upper,
            z3Upper: 3600.0 / speedZones.z3Upper,
            z4Upper: 3600.0 / speedZones.z4Upper
        )
    }

}


