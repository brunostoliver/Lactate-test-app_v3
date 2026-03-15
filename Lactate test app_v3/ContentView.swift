//
//  ContentView.swift
//  Lactate test app_v3
//
//  Created by Leonor Oliveira on 3/15/26.
//

import SwiftUI
import Charts

struct ContentView: View {
    @StateObject private var store = TestsStore()
    @State private var unitPreference: UnitPreference = .metric

    @State private var athleteName: String = ""
    @State private var sport: Sport = .running
    @State private var date: Date = Date()
    @State private var steps: [LactateStep] = [
        LactateStep(
            stepIndex: 1,
            lactate: nil,
            avgHeartRate: nil,
            runningPaceSecondsPerKm: nil,
            cyclingSpeedKmh: nil,
            powerWatts: nil
        )
    ]

    @State private var graphXAxis: GraphXAxis = .power
    @State private var selectedGraphPoint: GraphPoint? = nil
    @State private var comparedTestIDs: [UUID] = []
    @State private var showFullScreenChart: Bool = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    formSection
                    tableSection
                    comparisonSection
                    graphSection
                    thresholdsSection
                    trainingZonesSection
                    saveSection
                    savedTestsSection
                }
                .padding()
            }
            .navigationBarTitle("Lactate Test Intake", displayMode: .inline)
            .navigationBarItems(trailing: unitsPicker)
        }
        .fullScreenCover(isPresented: $showFullScreenChart) {
            FullScreenLactateChartView(
                title: "Lactate Curve",
                graphXAxis: graphXAxis,
                displaySeries: displaySeries,
                yAxisDomain: yAxisDomain,
                baseXAxisDomain: xAxisDomain,
                lt1Point: interpolatedThresholdPoint(targetLactate: 2.0),
                dmaxPoint: dmaxDisplayPoint,
                lt2Point: interpolatedThresholdPoint(targetLactate: 4.0),
                selectedPoint: $selectedGraphPoint,
                nearestPointProvider: { xValue in
                    nearestPoint(toX: xValue)
                },
                formatXAxisValue: { value in
                    formatXAxisValue(value)
                }
            )
        }
    }

    private var unitsPicker: some View {
        Picker("Units", selection: $unitPreference) {
            ForEach(UnitPreference.allCases) { unit in
                Text(unit == .metric ? "Metric" : "Imperial")
                    .tag(unit)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .frame(width: 220)
    }

    private var formSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Test Details")
                .font(.headline)

            TextField("Athlete name", text: $athleteName)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            Picker("Sport", selection: $sport) {
                ForEach(Sport.allCases) { s in
                    Text(s.rawValue.capitalized).tag(s)
                }
            }
            .pickerStyle(SegmentedPickerStyle())

            DatePicker("Date", selection: $date, displayedComponents: .date)

            VStack(alignment: .leading, spacing: 8) {
                Text("Sample Tests")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Button(action: {
                    loadSampleTest1()
                }) {
                    HStack {
                        Image(systemName: "doc.badge.plus")
                        Text("Load Test Sample 1")
                    }
                }

                Button(action: {
                    loadSampleTest2()
                }) {
                    HStack {
                        Image(systemName: "doc.badge.plus")
                        Text("Load Test Sample 2")
                    }
                }

                Button(action: {
                    loadSampleTest3()
                }) {
                    HStack {
                        Image(systemName: "doc.badge.plus")
                        Text("Load Test Sample 3")
                    }
                }
            }

            Divider()

            Text("Steps")
                .font(.headline)

            ForEach($steps) { $step in
                StepEditor(step: $step, sport: sport)
            }

            HStack {
                Button(action: {
                    let nextIndex = (steps.map { $0.stepIndex }.max() ?? 0) + 1
                    steps.append(
                        LactateStep(
                            stepIndex: nextIndex,
                            lactate: nil,
                            avgHeartRate: nil,
                            runningPaceSecondsPerKm: nil,
                            cyclingSpeedKmh: nil,
                            powerWatts: nil
                        )
                    )
                }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add Step")
                    }
                }

                if !steps.isEmpty {
                    Button(action: {
                        _ = steps.popLast()
                        if steps.isEmpty {
                            steps = [
                                LactateStep(
                                    stepIndex: 1,
                                    lactate: nil,
                                    avgHeartRate: nil,
                                    runningPaceSecondsPerKm: nil,
                                    cyclingSpeedKmh: nil,
                                    powerWatts: nil
                                )
                            ]
                        }
                        selectedGraphPoint = nil
                    }) {
                        HStack {
                            Image(systemName: "minus")
                            Text("Remove Last")
                        }
                    }
                    .foregroundColor(.red)
                }
            }
        }
    }

    private var tableSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Input Summary")
                .font(.headline)

            HStack {
                Text("#").frame(width: 24, alignment: .leading)
                Text("Lactate").frame(width: 90, alignment: .leading)
                Text("HR").frame(width: 50, alignment: .leading)

                if sport == .running {
                    Text("Pace").frame(width: 110, alignment: .leading)
                } else {
                    Text("Speed").frame(width: 100, alignment: .leading)
                }

                Text("Power").frame(width: 80, alignment: .leading)
            }
            .font(.caption)
            .foregroundColor(.secondary)

            ForEach(steps) { step in
                HStack {
                    Text("\(step.stepIndex)")
                        .frame(width: 24, alignment: .leading)

                    Text(step.lactate != nil ? String(format: "%.2f mmol/L", step.lactate!) : "-")
                        .frame(width: 90, alignment: .leading)

                    Text(step.avgHeartRate != nil ? "\(step.avgHeartRate!)" : "-")
                        .frame(width: 50, alignment: .leading)

                    if sport == .running {
                        Text(
                            step.runningPaceSecondsPerKm != nil
                            ? PaceFormatter.string(fromSecondsPerKm: step.runningPaceSecondsPerKm!, unit: unitPreference)
                            : "-"
                        )
                        .frame(width: 110, alignment: .leading)
                    } else {
                        Text(
                            step.cyclingSpeedKmh != nil
                            ? SpeedFormatter.string(fromKmh: step.cyclingSpeedKmh!, unit: unitPreference)
                            : "-"
                        )
                        .frame(width: 100, alignment: .leading)
                    }

                    Text(step.powerWatts != nil ? "\(step.powerWatts!) W" : "-")
                        .frame(width: 80, alignment: .leading)
                }
                .font(.subheadline)
            }
        }
    }

    private var comparisonSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            Text("Comparison")
                .font(.headline)

            Text("The graph always includes the current input test. You may add up to 2 saved tests for comparison.")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                comparisonLegendRow(
                    colorName: "blue",
                    title: currentSeriesLabel,
                    subtitle: "Current input"
                )

                if selectedComparisonTests.indices.contains(0) {
                    let test = selectedComparisonTests[0]
                    comparisonLegendRow(
                        colorName: "orange",
                        title: testLabel(for: test),
                        subtitle: "Comparison 1"
                    )
                }

                if selectedComparisonTests.indices.contains(1) {
                    let test = selectedComparisonTests[1]
                    comparisonLegendRow(
                        colorName: "purple",
                        title: testLabel(for: test),
                        subtitle: "Comparison 2"
                    )
                }
            }
            .padding(8)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
        }
    }

    private func comparisonLegendRow(colorName: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(colorForSeriesName(colorName))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var graphSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()

            HStack {
                Text("Lactate Curve")
                    .font(.headline)

                Spacer()

                Button(action: {
                    showFullScreenChart = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                        Text("Full Screen")
                    }
                    .font(.caption)
                }
                .disabled(currentGraphPoints.count < 2)
            }

            Picker("X Axis", selection: $graphXAxis) {
                ForEach(GraphXAxis.allCases) { axis in
                    Text(axis.title).tag(axis)
                }
            }
            .pickerStyle(SegmentedPickerStyle())

            if currentGraphPoints.count < 2 {
                Text("Enter at least two valid current-input points with lactate and the selected X-axis value to display the graph.")
                    .foregroundColor(.secondary)
            } else {
                LactateChartView(
                    graphXAxis: graphXAxis,
                    displaySeries: displaySeries,
                    yAxisDomain: yAxisDomain,
                    xAxisDomain: xAxisDomain,
                    lt1Point: interpolatedThresholdPoint(targetLactate: 2.0),
                    dmaxPoint: dmaxDisplayPoint,
                    lt2Point: interpolatedThresholdPoint(targetLactate: 4.0),
                    selectedPoint: $selectedGraphPoint,
                    nearestPointProvider: { xValue in
                        nearestPoint(toX: xValue)
                    },
                    formatXAxisValue: { value in
                        formatXAxisValue(value)
                    }
                )
                .frame(height: 340)

                if let selected = selectedGraphPoint {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Selected Point")
                            .font(.subheadline)
                            .bold()
                        Text(selected.seriesLabel)
                        Text("Step \(selected.stepIndex)")
                        Text("\(graphXAxis.title): \(formatXAxisValue(selected.x))")
                        Text(String(format: "Lactate: %.2f mmol/L", selected.lactate))
                        if let hr = selected.heartRate {
                            Text("Heart rate: \(hr) bpm")
                        }
                        if let power = selected.power {
                            Text("Power: \(power) W")
                        }
                    }
                    .font(.caption)
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                }
            }
        }
    }

    private var thresholdsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            Text("Threshold Summary (Current Input)")
                .font(.headline)

            if currentGraphPoints.count < 2 {
                Text("Not enough current-input data to estimate thresholds.")
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    if let lt1 = interpolatedThresholdPoint(targetLactate: 2.0) {
                        Text("LT1 (2.0 mmol/L): \(formatXAxisValue(lt1.x))")
                            .foregroundColor(.green)
                    } else {
                        Text("LT1 (2.0 mmol/L): not reached in the current data")
                            .foregroundColor(.secondary)
                    }

                    if let dmaxLactate = primaryDmaxLactate,
                       let dmax = interpolatedThresholdPoint(targetLactate: dmaxLactate) {
                        Text("Dmax: \(formatXAxisValue(dmax.x)) at lactate \(String(format: "%.2f", dmaxLactate)) mmol/L")
                            .foregroundColor(.purple)
                    } else {
                        Text("Dmax: not enough data")
                            .foregroundColor(.secondary)
                    }

                    if let lt2 = interpolatedThresholdPoint(targetLactate: 4.0) {
                        Text("LT2 (4.0 mmol/L): \(formatXAxisValue(lt2.x))")
                            .foregroundColor(.red)
                    } else {
                        Text("LT2 (4.0 mmol/L): not reached in the current data")
                            .foregroundColor(.secondary)
                    }
                }
                .font(.caption)
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            }
        }
    }

    private var trainingZonesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()

            Text("Training Zones (Current Input)")
                .font(.headline)

            if let powerThresholds = powerZoneThresholds {
                zoneCard(
                    title: "Power",
                    zone1: "Z1: < \(formatPower(powerThresholds.lt1))",
                    zone2: "Z2: \(formatPower(powerThresholds.lt1)) to \(formatPower(powerThresholds.dmax))",
                    zone3: "Z3: \(formatPower(powerThresholds.dmax)) to \(formatPower(powerThresholds.lt2))",
                    zone4: "Z4: > \(formatPower(powerThresholds.lt2))"
                )
            }

            if let hrThresholds = heartRateZoneThresholds {
                zoneCard(
                    title: "Heart Rate",
                    zone1: "Z1: < \(formatHeartRate(hrThresholds.lt1))",
                    zone2: "Z2: \(formatHeartRate(hrThresholds.lt1)) to \(formatHeartRate(hrThresholds.dmax))",
                    zone3: "Z3: \(formatHeartRate(hrThresholds.dmax)) to \(formatHeartRate(hrThresholds.lt2))",
                    zone4: "Z4: > \(formatHeartRate(hrThresholds.lt2))"
                )
            }

            if sport == .running, let paceThresholds = runningPaceZoneThresholds {
                zoneCard(
                    title: "Pace",
                    zone1: "Z1: slower than \(formatPace(paceThresholds.lt1))",
                    zone2: "Z2: \(formatPace(paceThresholds.lt1)) to \(formatPace(paceThresholds.dmax))",
                    zone3: "Z3: \(formatPace(paceThresholds.dmax)) to \(formatPace(paceThresholds.lt2))",
                    zone4: "Z4: faster than \(formatPace(paceThresholds.lt2))"
                )
            }

            if sport == .cycling, let speedThresholds = cyclingSpeedZoneThresholds {
                zoneCard(
                    title: "Speed",
                    zone1: "Z1: < \(formatSpeed(speedThresholds.lt1))",
                    zone2: "Z2: \(formatSpeed(speedThresholds.lt1)) to \(formatSpeed(speedThresholds.dmax))",
                    zone3: "Z3: \(formatSpeed(speedThresholds.dmax)) to \(formatSpeed(speedThresholds.lt2))",
                    zone4: "Z4: > \(formatSpeed(speedThresholds.lt2))"
                )
            }

            if powerZoneThresholds == nil &&
                heartRateZoneThresholds == nil &&
                runningPaceZoneThresholds == nil &&
                cyclingSpeedZoneThresholds == nil {
                Text("Not enough data to calculate zones.")
                    .foregroundColor(.secondary)
            }
        }
    }

    private func zoneCard(title: String, zone1: String, zone2: String, zone3: String, zone4: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .bold()
            Text(zone1)
            Text(zone2)
            Text(zone3)
            Text(zone4)
        }
        .font(.caption)
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }

    private var currentGraphPoints: [GraphPoint] {
        graphPoints(for: steps, seriesLabel: currentSeriesLabel, seriesColor: .blue)
    }

    private var currentSeriesLabel: String {
        let trimmed = athleteName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Current Input"
        }
        return "\(trimmed) (\(shortDateString(date)))"
    }

    private var selectedComparisonTests: [LactateTest] {
        store.tests.filter { comparedTestIDs.contains($0.id) }
            .sorted { comparedTestIDs.firstIndex(of: $0.id)! < comparedTestIDs.firstIndex(of: $1.id)! }
    }

    private var displaySeries: [GraphSeries] {
        var series: [GraphSeries] = []

        let current = currentGraphPoints
        if !current.isEmpty {
            series.append(
                GraphSeries(
                    id: "current",
                    label: currentSeriesLabel,
                    color: .blue,
                    points: current
                )
            )
        }

        let colors: [Color] = [.orange, .purple]
        for (index, test) in selectedComparisonTests.enumerated() {
            let points = graphPoints(for: test.steps, seriesLabel: testLabel(for: test), seriesColor: colors[index])
            if !points.isEmpty {
                series.append(
                    GraphSeries(
                        id: test.id.uuidString,
                        label: testLabel(for: test),
                        color: colors[index],
                        points: points
                    )
                )
            }
        }

        return series
    }

    private var allDisplayedGraphPoints: [GraphPoint] {
        displaySeries.flatMap { $0.points }
    }

    private func graphPoints(for testSteps: [LactateStep], seriesLabel: String, seriesColor: Color) -> [GraphPoint] {
        let raw: [GraphPoint] = testSteps.compactMap { step in
            guard let lactate = step.lactate else { return nil }

            switch graphXAxis {
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
            }
        }

        return raw.sorted { $0.x < $1.x }
    }

    private func testLabel(for test: LactateTest) -> String {
        "\(test.athleteName) (\(shortDateString(test.date)))"
    }

    private func colorForSeriesName(_ name: String) -> Color {
        switch name {
        case "blue":
            return .blue
        case "orange":
            return .orange
        case "purple":
            return .purple
        default:
            return .gray
        }
    }

    private var yAxisDomain: ClosedRange<Double> {
        let maxLactate = max(allDisplayedGraphPoints.map { $0.lactate }.max() ?? 6.0, 4.5)
        return 0.0...(maxLactate + 0.8)
    }

    private var xAxisDomain: ClosedRange<Double> {
        let allX = allDisplayedGraphPoints.map { $0.x }
        guard let first = allX.min(), let last = allX.max() else {
            return 0.0...100.0
        }

        let lowerPadding: Double
        let upperPadding: Double

        switch graphXAxis {
        case .heartRate:
            lowerPadding = 8.0
            upperPadding = 5.0
        case .power:
            lowerPadding = 15.0
            upperPadding = 10.0
        }

        let minX = max(0.0, first - lowerPadding)
        let maxX = last + upperPadding

        if maxX <= minX {
            return minX...(minX + 1.0)
        }

        return minX...maxX
    }

    private func interpolatedThresholdPoint(targetLactate: Double) -> ThresholdPoint? {
        let points = currentGraphPoints
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

    private var primaryWorkloadPoints: [WorkloadLactatePoint] {
        switch sport {
        case .cycling:
            let powerPoints = steps.compactMap { step -> WorkloadLactatePoint? in
                guard let power = step.powerWatts, let lactate = step.lactate else { return nil }
                return WorkloadLactatePoint(workload: Double(power), lactate: lactate)
            }
            .sorted { $0.workload < $1.workload }

            if powerPoints.count >= 3 { return powerPoints }

            let speedPoints = steps.compactMap { step -> WorkloadLactatePoint? in
                guard let speed = step.cyclingSpeedKmh, let lactate = step.lactate else { return nil }
                return WorkloadLactatePoint(workload: speed, lactate: lactate)
            }
            .sorted { $0.workload < $1.workload }

            if speedPoints.count >= 3 { return speedPoints }

            let hrPoints = steps.compactMap { step -> WorkloadLactatePoint? in
                guard let hr = step.avgHeartRate, let lactate = step.lactate else { return nil }
                return WorkloadLactatePoint(workload: Double(hr), lactate: lactate)
            }
            .sorted { $0.workload < $1.workload }

            return hrPoints

        case .running:
            let paceSpeedPoints = steps.compactMap { step -> WorkloadLactatePoint? in
                guard let paceSeconds = step.runningPaceSecondsPerKm,
                      let lactate = step.lactate,
                      paceSeconds > 0 else { return nil }
                let speedKmh = 3600.0 / Double(paceSeconds)
                return WorkloadLactatePoint(workload: speedKmh, lactate: lactate)
            }
            .sorted { $0.workload < $1.workload }

            if paceSpeedPoints.count >= 3 { return paceSpeedPoints }

            let powerPoints = steps.compactMap { step -> WorkloadLactatePoint? in
                guard let power = step.powerWatts, let lactate = step.lactate else { return nil }
                return WorkloadLactatePoint(workload: Double(power), lactate: lactate)
            }
            .sorted { $0.workload < $1.workload }

            if powerPoints.count >= 3 { return powerPoints }

            let hrPoints = steps.compactMap { step -> WorkloadLactatePoint? in
                guard let hr = step.avgHeartRate, let lactate = step.lactate else { return nil }
                return WorkloadLactatePoint(workload: Double(hr), lactate: lactate)
            }
            .sorted { $0.workload < $1.workload }

            return hrPoints
        }
    }

    private var primaryDmaxLactate: Double? {
        dmaxPoint(from: primaryWorkloadPoints)?.lactate
    }

    private var dmaxDisplayPoint: ThresholdPoint? {
        guard let dmaxLactate = primaryDmaxLactate else { return nil }
        return interpolatedThresholdPoint(targetLactate: dmaxLactate)
    }

    private func dmaxPoint(from points: [WorkloadLactatePoint]) -> WorkloadLactatePoint? {
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

    private func metricThresholds(from pairs: [MetricLactatePair], dmaxLactate: Double?) -> MetricThresholds? {
        guard let dmaxLactate = dmaxLactate else { return nil }

        let sortedPairs = pairs.sorted { $0.metric < $1.metric }

        guard let lt1 = interpolatedMetric(atLactate: 2.0, from: sortedPairs),
              let dmax = interpolatedMetric(atLactate: dmaxLactate, from: sortedPairs),
              let lt2 = interpolatedMetric(atLactate: 4.0, from: sortedPairs) else {
            return nil
        }

        return MetricThresholds(lt1: lt1, dmax: dmax, lt2: lt2)
    }

    private func interpolatedMetric(atLactate targetLactate: Double, from pairs: [MetricLactatePair]) -> Double? {
        guard pairs.count >= 2 else { return nil }

        for index in 0..<(pairs.count - 1) {
            let p1 = pairs[index]
            let p2 = pairs[index + 1]

            let y1 = p1.lactate
            let y2 = p2.lactate

            if y1 == targetLactate {
                return p1.metric
            }

            if y2 == targetLactate {
                return p2.metric
            }

            let crossesUp = y1 < targetLactate && y2 > targetLactate
            let crossesDown = y1 > targetLactate && y2 < targetLactate

            if crossesUp || crossesDown {
                let fraction = (targetLactate - y1) / (y2 - y1)
                return p1.metric + fraction * (p2.metric - p1.metric)
            }
        }

        return nil
    }

    private var heartRateZoneThresholds: MetricThresholds? {
        let pairs = steps.compactMap { step -> MetricLactatePair? in
            guard let hr = step.avgHeartRate, let lactate = step.lactate else { return nil }
            return MetricLactatePair(metric: Double(hr), lactate: lactate)
        }
        return metricThresholds(from: pairs, dmaxLactate: primaryDmaxLactate)
    }

    private var powerZoneThresholds: MetricThresholds? {
        let pairs = steps.compactMap { step -> MetricLactatePair? in
            guard let power = step.powerWatts, let lactate = step.lactate else { return nil }
            return MetricLactatePair(metric: Double(power), lactate: lactate)
        }
        return metricThresholds(from: pairs, dmaxLactate: primaryDmaxLactate)
    }

    private var cyclingSpeedZoneThresholds: MetricThresholds? {
        let pairs = steps.compactMap { step -> MetricLactatePair? in
            guard let speed = step.cyclingSpeedKmh, let lactate = step.lactate else { return nil }
            return MetricLactatePair(metric: speed, lactate: lactate)
        }
        return metricThresholds(from: pairs, dmaxLactate: primaryDmaxLactate)
    }

    private var runningPaceZoneThresholds: MetricThresholds? {
        let pairs = steps.compactMap { step -> MetricLactatePair? in
            guard let paceSeconds = step.runningPaceSecondsPerKm,
                  let lactate = step.lactate,
                  paceSeconds > 0 else { return nil }
            let speedKmh = 3600.0 / Double(paceSeconds)
            return MetricLactatePair(metric: speedKmh, lactate: lactate)
        }

        guard let speedThresholds = metricThresholds(from: pairs, dmaxLactate: primaryDmaxLactate) else {
            return nil
        }

        let lt1Pace = 3600.0 / speedThresholds.lt1
        let dmaxPace = 3600.0 / speedThresholds.dmax
        let lt2Pace = 3600.0 / speedThresholds.lt2

        return MetricThresholds(lt1: lt1Pace, dmax: dmaxPace, lt2: lt2Pace)
    }

    private func nearestPoint(toX xValue: Double) -> GraphPoint? {
        guard !allDisplayedGraphPoints.isEmpty else { return nil }
        return allDisplayedGraphPoints.min { abs($0.x - xValue) < abs($1.x - xValue) }
    }

    private func formatXAxisValue(_ value: Double) -> String {
        switch graphXAxis {
        case .heartRate:
            return "\(Int(value.rounded())) bpm"
        case .power:
            return "\(Int(value.rounded())) W"
        }
    }

    private func formatHeartRate(_ value: Double) -> String {
        "\(Int(value.rounded())) bpm"
    }

    private func formatPower(_ value: Double) -> String {
        "\(Int(value.rounded())) W"
    }

    private func formatSpeed(_ value: Double) -> String {
        SpeedFormatter.string(fromKmh: value, unit: unitPreference)
    }

    private func formatPace(_ value: Double) -> String {
        PaceFormatter.string(fromSecondsPerKm: Int(value.rounded()), unit: unitPreference)
    }

    private var saveSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            HStack(spacing: 12) {
                Button(action: {
                    let test = LactateTest(
                        athleteName: athleteName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Test" : athleteName,
                        sport: sport,
                        date: date,
                        steps: steps
                    )
                    store.tests.append(test)
                    resetEntryFields()
                }) {
                    Text("Save Test")
                        .fontWeight(.semibold)
                }
                .disabled(
                    athleteName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    steps.isEmpty
                )

                Button(action: {
                    clearAllData()
                }) {
                    Text("Clear All")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.red)
            }
        }
    }

    private var savedTestsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            Text("Saved Tests")
                .font(.headline)

            if store.tests.isEmpty {
                Text("No tests saved yet.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(store.tests) { test in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(test.athleteName).bold()
                            Text(test.sport.rawValue.capitalized)
                            Text(shortDateString(test.date))
                        }

                        Text("Steps: \(test.steps.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack(spacing: 10) {
                            if isCompared(test) {
                                Button(action: {
                                    removeComparedTest(test)
                                }) {
                                    Text("Remove Comparison")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.red)
                            } else {
                                Button(action: {
                                    addComparedTest(test)
                                }) {
                                    Text("Compare")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                }
                                .disabled(!canAddMoreComparisons(for: test))
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func isCompared(_ test: LactateTest) -> Bool {
        comparedTestIDs.contains(test.id)
    }

    private func canAddMoreComparisons(for test: LactateTest) -> Bool {
        if comparedTestIDs.contains(test.id) {
            return true
        }
        return comparedTestIDs.count < 2
    }

    private func addComparedTest(_ test: LactateTest) {
        guard !comparedTestIDs.contains(test.id) else { return }
        guard comparedTestIDs.count < 2 else { return }
        comparedTestIDs.append(test.id)
        selectedGraphPoint = nil
    }

    private func removeComparedTest(_ test: LactateTest) {
        comparedTestIDs.removeAll { $0 == test.id }
        selectedGraphPoint = nil
    }

    private func resetEntryFields() {
        athleteName = ""
        sport = .running
        date = Date()
        steps = [
            LactateStep(
                stepIndex: 1,
                lactate: nil,
                avgHeartRate: nil,
                runningPaceSecondsPerKm: nil,
                cyclingSpeedKmh: nil,
                powerWatts: nil
            )
        ]
        graphXAxis = .power
        selectedGraphPoint = nil
    }

    private func clearAllData() {
        resetEntryFields()
        store.tests = []
        comparedTestIDs = []
    }

    private func loadSampleTest1() {
        loadCyclingSample(
            athleteName: "Sample Test 1",
            dateString: "04-29-23",
            lactates: [1.7, 1.3, 1.9, 2.4, 3.4, 7.1],
            heartRates: [114, 124, 127, 133, 138, 147],
            powers: [127, 124, 142, 162, 183, 204]
        )
    }

    private func loadSampleTest2() {
        loadCyclingSample(
            athleteName: "Sample Test 2",
            dateString: "04-04-23",
            lactates: [1.6, 1.7, 1.8, 3.2, 3.7, 7.2],
            heartRates: [107, 112, 119, 129, 132, 141],
            powers: [118, 122, 143, 163, 183, 209]
        )
    }

    private func loadSampleTest3() {
        loadCyclingSample(
            athleteName: "Sample Test 3",
            dateString: "02-25-23",
            lactates: [1.9, 1.7, 2.6, 3.8, 5.6],
            heartRates: [115, 119, 127, 136, 141],
            powers: [125, 122, 143, 164, 183]
        )
    }

    private func loadCyclingSample(
        athleteName: String,
        dateString: String,
        lactates: [Double],
        heartRates: [Int],
        powers: [Int]
    ) {
        self.athleteName = athleteName
        self.sport = .cycling
        self.graphXAxis = .power

        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd-yy"
        self.date = formatter.date(from: dateString) ?? Date()

        var loadedSteps: [LactateStep] = []
        let count = min(lactates.count, heartRates.count, powers.count)

        for index in 0..<count {
            loadedSteps.append(
                LactateStep(
                    stepIndex: index + 1,
                    lactate: lactates[index],
                    avgHeartRate: heartRates[index],
                    runningPaceSecondsPerKm: nil,
                    cyclingSpeedKmh: nil,
                    powerWatts: powers[index]
                )
            )
        }

        self.steps = loadedSteps
        self.selectedGraphPoint = nil
    }

    private func shortDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct LactateChartView: View {
    let graphXAxis: GraphXAxis
    let displaySeries: [GraphSeries]
    let yAxisDomain: ClosedRange<Double>
    let xAxisDomain: ClosedRange<Double>
    let lt1Point: ThresholdPoint?
    let dmaxPoint: ThresholdPoint?
    let lt2Point: ThresholdPoint?

    @Binding var selectedPoint: GraphPoint?

    let nearestPointProvider: (Double) -> GraphPoint?
    let formatXAxisValue: (Double) -> String

    var body: some View {
        Chart {
            RuleMark(y: .value("LT1", 2.0))
                .foregroundStyle(.green)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))

            RuleMark(y: .value("LT2", 4.0))
                .foregroundStyle(.red)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))

            ForEach(displaySeries) { series in
                ForEach(series.points) { point in
                    LineMark(
                        x: .value(graphXAxis.title, point.x),
                        y: .value("Lactate", point.lactate)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(series.color)
                }

                ForEach(series.points) { point in
                    PointMark(
                        x: .value(graphXAxis.title, point.x),
                        y: .value("Lactate", point.lactate)
                    )
                    .foregroundStyle(series.color)
                    .symbolSize(50)
                }
            }

            if let lt1 = lt1Point {
                RuleMark(x: .value("LT1 X", lt1.x))
                    .foregroundStyle(.green)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

                PointMark(
                    x: .value("LT1 Point X", lt1.x),
                    y: .value("LT1 Point Y", lt1.lactate)
                )
                .foregroundStyle(.green)
                .symbolSize(90)
            }

            if let dmax = dmaxPoint {
                RuleMark(x: .value("Dmax X", dmax.x))
                    .foregroundStyle(.purple)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

                PointMark(
                    x: .value("Dmax Point X", dmax.x),
                    y: .value("Dmax Point Y", dmax.lactate)
                )
                .foregroundStyle(.purple)
                .symbolSize(100)
            }

            if let lt2 = lt2Point {
                RuleMark(x: .value("LT2 X", lt2.x))
                    .foregroundStyle(.red)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

                PointMark(
                    x: .value("LT2 Point X", lt2.x),
                    y: .value("LT2 Point Y", lt2.lactate)
                )
                .foregroundStyle(.red)
                .symbolSize(90)
            }

            if let selected = selectedPoint {
                RuleMark(x: .value("Selected X", selected.x))
                    .foregroundStyle(.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

                PointMark(
                    x: .value("Selected Point X", selected.x),
                    y: .value("Selected Point Y", selected.lactate)
                )
                .foregroundStyle(selected.seriesColor)
                .symbolSize(130)
                .annotation(position: .top, alignment: .leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selected.seriesLabel)
                            .font(.caption)
                            .bold()
                        Text("Step \(selected.stepIndex)")
                            .font(.caption2)
                        Text("\(graphXAxis.title): \(formatXAxisValue(selected.x))")
                            .font(.caption2)
                        Text(String(format: "Lactate: %.2f", selected.lactate))
                            .font(.caption2)
                    }
                    .padding(6)
                    .background(Color(.systemBackground).opacity(0.95))
                    .cornerRadius(8)
                }
            }
        }
        .chartXAxisLabel(graphXAxis.title)
        .chartYAxisLabel("Lactate (mmol/L)")
        .chartYScale(domain: yAxisDomain)
        .chartXScale(domain: xAxisDomain)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let plotFrame = geometry[proxy.plotAreaFrame]
                                let relativeX = value.location.x - plotFrame.origin.x

                                guard relativeX >= 0, relativeX <= plotFrame.size.width else {
                                    return
                                }

                                if let xValue: Double = proxy.value(atX: relativeX) {
                                    selectedPoint = nearestPointProvider(xValue)
                                }
                            }
                    )
            }
        }
    }
}

struct FullScreenLactateChartView: View {
    let title: String
    let graphXAxis: GraphXAxis
    let displaySeries: [GraphSeries]
    let yAxisDomain: ClosedRange<Double>
    let baseXAxisDomain: ClosedRange<Double>
    let lt1Point: ThresholdPoint?
    let dmaxPoint: ThresholdPoint?
    let lt2Point: ThresholdPoint?

    @Binding var selectedPoint: GraphPoint?

    let nearestPointProvider: (Double) -> GraphPoint?
    let formatXAxisValue: (Double) -> String

    @Environment(\.dismiss) private var dismiss

    @State private var currentXAxisDomain: ClosedRange<Double> = 0.0...1.0
    @State private var pinchStartDomain: ClosedRange<Double> = 0.0...1.0

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Button(action: zoomIn) {
                        Label("Zoom In", systemImage: "plus.magnifyingglass")
                    }

                    Button(action: zoomOut) {
                        Label("Zoom Out", systemImage: "minus.magnifyingglass")
                    }

                    Button(action: resetZoom) {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }

                    Spacer()
                }
                .font(.caption)

                LactateChartView(
                    graphXAxis: graphXAxis,
                    displaySeries: displaySeries,
                    yAxisDomain: yAxisDomain,
                    xAxisDomain: currentXAxisDomain,
                    lt1Point: lt1Point,
                    dmaxPoint: dmaxPoint,
                    lt2Point: lt2Point,
                    selectedPoint: $selectedPoint,
                    nearestPointProvider: nearestPointProvider,
                    formatXAxisValue: formatXAxisValue
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            applyMagnification(value)
                        }
                )

                if let selected = selectedPoint {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Selected Point")
                            .font(.headline)
                        Text(selected.seriesLabel)
                        Text("Step \(selected.stepIndex)")
                        Text("\(graphXAxis.title): \(formatXAxisValue(selected.x))")
                        Text(String(format: "Lactate: %.2f mmol/L", selected.lactate))
                        if let hr = selected.heartRate {
                            Text("Heart rate: \(hr) bpm")
                        }
                        if let power = selected.power {
                            Text("Power: \(power) W")
                        }
                    }
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                }
            }
            .padding()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                currentXAxisDomain = baseXAxisDomain
                pinchStartDomain = baseXAxisDomain
            }
        }
    }

    private func zoomIn() {
        currentXAxisDomain = scaledDomain(from: currentXAxisDomain, scale: 0.8)
        pinchStartDomain = currentXAxisDomain
    }

    private func zoomOut() {
        currentXAxisDomain = scaledDomain(from: currentXAxisDomain, scale: 1.25)
        pinchStartDomain = currentXAxisDomain
    }

    private func resetZoom() {
        currentXAxisDomain = baseXAxisDomain
        pinchStartDomain = baseXAxisDomain
    }

    private func applyMagnification(_ value: CGFloat) {
        guard value > 0 else { return }
        let scale = 1.0 / Double(value)
        currentXAxisDomain = scaledDomain(from: pinchStartDomain, scale: scale)
    }

    private func scaledDomain(from domain: ClosedRange<Double>, scale: Double) -> ClosedRange<Double> {
        let baseMin = baseXAxisDomain.lowerBound
        let baseMax = baseXAxisDomain.upperBound
        let baseWidth = baseMax - baseMin

        let currentMin = domain.lowerBound
        let currentMax = domain.upperBound
        let currentWidth = currentMax - currentMin

        let center = (currentMin + currentMax) / 2.0
        var newWidth = currentWidth * scale

        let minimumWidth = max(baseWidth * 0.15, 1.0)
        let maximumWidth = baseWidth

        newWidth = max(minimumWidth, min(maximumWidth, newWidth))

        var newMin = center - newWidth / 2.0
        var newMax = center + newWidth / 2.0

        if newMin < baseMin {
            newMin = baseMin
            newMax = newMin + newWidth
        }

        if newMax > baseMax {
            newMax = baseMax
            newMin = newMax - newWidth
        }

        if newMin < baseMin {
            newMin = baseMin
        }

        if newMax > baseMax {
            newMax = baseMax
        }

        return newMin...newMax
    }
}

struct StepEditor: View {
    @Binding var step: LactateStep
    let sport: Sport

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Step \(step.stepIndex)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                TextField("Lactate (mmol/L)", text: doubleStringBinding($step.lactate))
                    .keyboardType(.decimalPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                TextField("Avg HR", text: intStringBinding($step.avgHeartRate))
                    .keyboardType(.numberPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                if sport == .running {
                    PaceInput(secondsPerKm: $step.runningPaceSecondsPerKm)
                } else {
                    TextField("Speed (km/h)", text: doubleStringBinding($step.cyclingSpeedKmh))
                        .keyboardType(.decimalPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                TextField("Power (W)", text: intStringBinding($step.powerWatts))
                    .keyboardType(.numberPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func intStringBinding(_ value: Binding<Int?>) -> Binding<String> {
        Binding<String>(
            get: {
                if let wrapped = value.wrappedValue {
                    return String(wrapped)
                }
                return ""
            },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    value.wrappedValue = nil
                } else {
                    value.wrappedValue = Int(trimmed)
                }
            }
        )
    }

    private func doubleStringBinding(_ value: Binding<Double?>) -> Binding<String> {
        Binding<String>(
            get: {
                if let wrapped = value.wrappedValue {
                    return String(wrapped)
                }
                return ""
            },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    value.wrappedValue = nil
                } else {
                    let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
                    value.wrappedValue = Double(normalized)
                }
            }
        )
    }
}

struct PaceInput: View {
    @Binding var secondsPerKm: Int?
    @State private var minutes: String = ""
    @State private var seconds: String = ""

    var body: some View {
        HStack(spacing: 4) {
            Text("Pace")

            TextField("min", text: Binding(
                get: { minutes },
                set: { newValue in
                    minutes = newValue
                    updateBinding()
                }
            ))
            .keyboardType(.numberPad)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .frame(width: 50)

            Text(":")

            TextField("sec", text: Binding(
                get: { seconds },
                set: { newValue in
                    seconds = newValue
                    updateBinding()
                }
            ))
            .keyboardType(.numberPad)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .frame(width: 50)

            Text("min/km")
        }
        .onAppear(perform: syncFromBinding)
    }

    private func syncFromBinding() {
        guard let total = secondsPerKm else {
            minutes = ""
            seconds = ""
            return
        }

        minutes = String(total / 60)
        seconds = String(format: "%02d", total % 60)
    }

    private func updateBinding() {
        let m = Int(minutes) ?? 0
        let s = Int(seconds) ?? 0
        let clampedS = max(0, min(59, s))
        let total = m * 60 + clampedS
        secondsPerKm = total > 0 ? total : nil
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

struct MetricThresholds {
    let lt1: Double
    let dmax: Double
    let lt2: Double
}

#Preview {
    ContentView()
}
