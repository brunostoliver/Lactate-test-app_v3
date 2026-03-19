import SwiftUI

extension ContentView {


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

