//
//  ContentView.swift
//  Lactate test app_v3
//
//  Created by Bruno Oliveira on 3/15/26.
//

import SwiftUI
import Charts

struct ContentView: View {
    @ObservedObject var store: SwiftDataTestsStore
    @State private var unitPreference: UnitPreference = .metric

    @State private var draft = LactateTestDraft()

    @State private var graphXAxis: GraphXAxis = .power
    @State private var selectedGraphPoint: GraphPoint? = nil
    @State private var comparedTestIDs: [UUID] = []
    @State private var showFullScreenChart: Bool = false
    @State private var showDeleteSavedTestsAlert: Bool = false
    @State private var editingTest: LactateTest? = nil

    init(store: SwiftDataTestsStore) {
        self.store = store
    }

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
        .alert("Delete all saved tests?", isPresented: $showDeleteSavedTestsAlert) {
            Button("Delete", role: .destructive) {
                deleteSavedTests()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently erase all saved lactate tests stored in the app.")
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
            HStack {
                Text(editingTest == nil ? "Test Details" : "Editing Saved Test")
                    .font(.headline)

                Spacer()

                if let editingTest {
                    Text(shortDateString(editingTest.date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if editingTest != nil {
                Text("You are editing an existing saved test. Tap Save Test to update it.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            TextField("Athlete name", text: $draft.athleteName)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            Picker("Sport", selection: $draft.sport) {
                ForEach(Sport.allCases) { s in
                    Text(s.rawValue.capitalized).tag(s)
                }
            }
            .pickerStyle(SegmentedPickerStyle())

            DatePicker("Date", selection: $draft.date, displayedComponents: .date)

            VStack(alignment: .leading, spacing: 8) {
                Text("Sample Tests")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Button(action: loadSampleTest1) {
                    HStack {
                        Image(systemName: "doc.badge.plus")
                        Text("Load Test Sample 1")
                    }
                }

                Button(action: loadSampleTest2) {
                    HStack {
                        Image(systemName: "doc.badge.plus")
                        Text("Load Test Sample 2")
                    }
                }

                Button(action: loadSampleTest3) {
                    HStack {
                        Image(systemName: "doc.badge.plus")
                        Text("Load Test Sample 3")
                    }
                }
            }

            Divider()

            Text("Steps")
                .font(.headline)

            ForEach($draft.steps) { $step in
                StepEditor(step: $step, sport: draft.sport)
            }

            HStack {
                Button(action: addStep) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add Step")
                    }
                }

                if !draft.steps.isEmpty {
                    Button(action: removeLastStep) {
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

    private func addStep() {
        let nextIndex = (draft.steps.map { $0.stepIndex }.max() ?? 0) + 1
        draft.steps.append(LactateStep.emptyStep(stepIndex: nextIndex))
    }

    private func removeLastStep() {
        _ = draft.steps.popLast()
        if draft.steps.isEmpty {
            draft.steps = [LactateStep.emptyStep(stepIndex: 1)]
        }
        selectedGraphPoint = nil
    }

    private var tableSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Input Summary")
                .font(.headline)

            HStack {
                Text("#").frame(width: 24, alignment: .leading)
                Text("Lactate").frame(width: 90, alignment: .leading)
                Text("HR").frame(width: 50, alignment: .leading)

                if draft.sport == .running {
                    Text("Pace").frame(width: 110, alignment: .leading)
                } else {
                    Text("Speed").frame(width: 100, alignment: .leading)
                }

                Text("Power").frame(width: 80, alignment: .leading)
            }
            .font(.caption)
            .foregroundColor(.secondary)

            ForEach(draft.steps) { step in
                HStack {
                    Text("\(step.stepIndex)")
                        .frame(width: 24, alignment: .leading)

                    Text(step.lactate != nil ? String(format: "%.2f mmol/L", step.lactate!) : "-")
                        .frame(width: 90, alignment: .leading)

                    Text(step.avgHeartRate != nil ? "\(step.avgHeartRate!)" : "-")
                        .frame(width: 50, alignment: .leading)

                    if draft.sport == .running {
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

                    if let modified = modifiedDmaxResult {
                        Text("Modified Dmax (Newell): \(formatPrimaryWorkload(modified.workload)) at lactate \(String(format: "%.2f", modified.lactate)) mmol/L")
                            .foregroundColor(.indigo)
                    } else {
                        Text("Modified Dmax (Newell): not enough data")
                            .foregroundColor(.secondary)
                    }

                    if let logLog = logLogBreakpointResult {
                        Text("Log-log breakpoint: \(formatPrimaryWorkload(logLog.workload)) at lactate \(String(format: "%.2f", logLog.lactate)) mmol/L")
                            .foregroundColor(.brown)
                    } else {
                        Text("Log-log breakpoint: not enough data")
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

            Text("5-Zone Training Model (Current Input)")
                .font(.headline)

            if let powerZones = powerFiveZones {
                fiveZoneCardIncreasing(
                    title: "Power",
                    z1: "Z1 Recovery: < \(formatPower(powerZones.z1Upper))",
                    z2: "Z2 Endurance: \(formatPower(powerZones.z1Upper)) to \(formatPower(powerZones.z2Upper))",
                    z3: "Z3 Tempo: \(formatPower(powerZones.z2Upper)) to \(formatPower(powerZones.z3Upper))",
                    z4: "Z4 Threshold: \(formatPower(powerZones.z3Upper)) to \(formatPower(powerZones.z4Upper))",
                    z5: "Z5 VO₂max: > \(formatPower(powerZones.z4Upper))"
                )
            }

            if let hrZones = heartRateFiveZones {
                fiveZoneCardIncreasing(
                    title: "Heart Rate",
                    z1: "Z1 Recovery: < \(formatHeartRate(hrZones.z1Upper))",
                    z2: "Z2 Endurance: \(formatHeartRate(hrZones.z1Upper)) to \(formatHeartRate(hrZones.z2Upper))",
                    z3: "Z3 Tempo: \(formatHeartRate(hrZones.z2Upper)) to \(formatHeartRate(hrZones.z3Upper))",
                    z4: "Z4 Threshold: \(formatHeartRate(hrZones.z3Upper)) to \(formatHeartRate(hrZones.z4Upper))",
                    z5: "Z5 VO₂max: > \(formatHeartRate(hrZones.z4Upper))"
                )
            }

            if draft.sport == .cycling, let speedZones = cyclingSpeedFiveZones {
                fiveZoneCardIncreasing(
                    title: "Speed",
                    z1: "Z1 Recovery: < \(formatSpeed(speedZones.z1Upper))",
                    z2: "Z2 Endurance: \(formatSpeed(speedZones.z1Upper)) to \(formatSpeed(speedZones.z2Upper))",
                    z3: "Z3 Tempo: \(formatSpeed(speedZones.z2Upper)) to \(formatSpeed(speedZones.z3Upper))",
                    z4: "Z4 Threshold: \(formatSpeed(speedZones.z3Upper)) to \(formatSpeed(speedZones.z4Upper))",
                    z5: "Z5 VO₂max: > \(formatSpeed(speedZones.z4Upper))"
                )
            }

            if draft.sport == .running, let paceZones = runningPaceFiveZones {
                fiveZoneCardDecreasing(
                    title: "Pace",
                    z1: "Z1 Recovery: slower than \(formatPace(paceZones.z1Upper))",
                    z2: "Z2 Endurance: \(formatPace(paceZones.z1Upper)) to \(formatPace(paceZones.z2Upper))",
                    z3: "Z3 Tempo: \(formatPace(paceZones.z2Upper)) to \(formatPace(paceZones.z3Upper))",
                    z4: "Z4 Threshold: \(formatPace(paceZones.z3Upper)) to \(formatPace(paceZones.z4Upper))",
                    z5: "Z5 VO₂max: faster than \(formatPace(paceZones.z4Upper))"
                )
            }

            if powerFiveZones == nil &&
                heartRateFiveZones == nil &&
                runningPaceFiveZones == nil &&
                cyclingSpeedFiveZones == nil {
                Text("Not enough data to calculate 5-zone training ranges.")
                    .foregroundColor(.secondary)
            }
        }
    }

    private func fiveZoneCardIncreasing(
        title: String,
        z1: String,
        z2: String,
        z3: String,
        z4: String,
        z5: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .bold()
            Text(z1)
            Text(z2)
            Text(z3)
            Text(z4)
            Text(z5)
        }
        .font(.caption)
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }

    private func fiveZoneCardDecreasing(
        title: String,
        z1: String,
        z2: String,
        z3: String,
        z4: String,
        z5: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .bold()
            Text(z1)
            Text(z2)
            Text(z3)
            Text(z4)
            Text(z5)
        }
        .font(.caption)
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }

    private func nearestPoint(toX xValue: Double) -> GraphPoint? {
        guard !allDisplayedGraphPoints.isEmpty else { return nil }
        return allDisplayedGraphPoints.min { abs($0.x - xValue) < abs($1.x - xValue) }
    }

    private var currentGraphPoints: [GraphPoint] {
        graphPoints(for: draft.steps, seriesLabel: currentSeriesLabel, seriesColor: .blue)
    }

    private var currentSeriesLabel: String {
        let trimmed = draft.athleteName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Current Input"
        }
        return "\(trimmed) (\(shortDateString(draft.date)))"
    }

    private var selectedComparisonTests: [LactateTest] {
        store.tests
            .filter { comparedTestIDs.contains($0.id) }
            .sorted { lhs, rhs in
                (comparedTestIDs.firstIndex(of: lhs.id) ?? 0) < (comparedTestIDs.firstIndex(of: rhs.id) ?? 0)
            }
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
            let points = graphPoints(
                for: test.steps,
                seriesLabel: testLabel(for: test),
                seriesColor: colors[index]
            )
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

            let hrPoints = draft.steps.compactMap { step -> WorkloadLactatePoint? in
                guard let hr = step.avgHeartRate, let lactate = step.lactate else { return nil }
                return WorkloadLactatePoint(workload: Double(hr), lactate: lactate)
            }
            .sorted { $0.workload < $1.workload }

            return hrPoints

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

            let hrPoints = draft.steps.compactMap { step -> WorkloadLactatePoint? in
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

    private var modifiedDmaxResult: WorkloadThresholdResult? {
        modifiedDmaxPoint(from: primaryWorkloadPoints)
    }

    private var logLogBreakpointResult: WorkloadThresholdResult? {
        logLogBreakpoint(from: primaryWorkloadPoints)
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

    private func modifiedDmaxPoint(from points: [WorkloadLactatePoint]) -> WorkloadThresholdResult? {
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

    private func logLogBreakpoint(from points: [WorkloadLactatePoint]) -> WorkloadThresholdResult? {
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

    private func linearRegression(for data: [(x: Double, y: Double)]) -> LinearRegressionResult? {
        guard data.count >= 2 else { return nil }

        let n = Double(data.count)
        let sumX = data.reduce(0.0) { partial, point in partial + point.x }
        let sumY = data.reduce(0.0) { partial, point in partial + point.y }
        let sumXX = data.reduce(0.0) { partial, point in partial + (point.x * point.x) }
        let sumXY = data.reduce(0.0) { partial, point in partial + (point.x * point.y) }

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

    private var preferredMiddleLactate: Double? {
        modifiedDmaxResult?.lactate ?? primaryDmaxLactate
    }

    private func interpolatedMetric(atLactate targetLactate: Double, from pairs: [MetricLactatePair]) -> Double? {
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

    private func fiveZonesIncreasing(from pairs: [MetricLactatePair], middleLactate: Double?) -> FiveZoneThresholds? {
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

    private var heartRateFiveZones: FiveZoneThresholds? {
        let pairs = draft.steps.compactMap { step -> MetricLactatePair? in
            guard let hr = step.avgHeartRate, let lactate = step.lactate else { return nil }
            return MetricLactatePair(metric: Double(hr), lactate: lactate)
        }
        return fiveZonesIncreasing(from: pairs, middleLactate: preferredMiddleLactate)
    }

    private var powerFiveZones: FiveZoneThresholds? {
        let pairs = draft.steps.compactMap { step -> MetricLactatePair? in
            guard let power = step.powerWatts, let lactate = step.lactate else { return nil }
            return MetricLactatePair(metric: Double(power), lactate: lactate)
        }
        return fiveZonesIncreasing(from: pairs, middleLactate: preferredMiddleLactate)
    }

    private var cyclingSpeedFiveZones: FiveZoneThresholds? {
        let pairs = draft.steps.compactMap { step -> MetricLactatePair? in
            guard let speed = step.cyclingSpeedKmh, let lactate = step.lactate else { return nil }
            return MetricLactatePair(metric: speed, lactate: lactate)
        }
        return fiveZonesIncreasing(from: pairs, middleLactate: preferredMiddleLactate)
    }

    private var runningPaceFiveZones: FiveZoneThresholds? {
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

    private var primaryWorkloadLabel: String {
        switch draft.sport {
        case .cycling:
            if draft.steps.contains(where: { $0.powerWatts != nil && $0.lactate != nil }) {
                return "Power"
            }
            if draft.steps.contains(where: { $0.cyclingSpeedKmh != nil && $0.lactate != nil }) {
                return "Speed"
            }
            return "Heart Rate"

        case .running:
            if draft.steps.contains(where: { $0.runningPaceSecondsPerKm != nil && $0.lactate != nil }) {
                return "Speed"
            }
            if draft.steps.contains(where: { $0.powerWatts != nil && $0.lactate != nil }) {
                return "Power"
            }
            return "Heart Rate"
        }
    }

    private func formatPrimaryWorkload(_ value: Double) -> String {
        switch primaryWorkloadLabel {
        case "Power":
            return formatPower(value)
        case "Speed":
            return formatSpeed(value)
        default:
            return formatHeartRate(value)
        }
    }

    private var saveSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            HStack(spacing: 12) {
                Button(action: saveCurrentTest) {
                    Text(editingTest == nil ? "Save Test" : "Update Test")
                        .fontWeight(.semibold)
                }
                .disabled(
                    draft.athleteName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    draft.steps.isEmpty
                )

                Button(action: resetForm) {
                    Text(editingTest == nil ? "Reset Form" : "Cancel Edit")
                        .fontWeight(.semibold)
                }

                Button(action: {
                    showDeleteSavedTestsAlert = true
                }) {
                    Text("Delete Saved Tests")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.red)
            }
        }
    }

    private func saveCurrentTest() {
        if let editingTest {
            store.updateTest(editingTest, with: draft)
        } else {
            store.appendTest(draft.asLactateTest())
        }

        resetEntryFields()
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
                            Button(action: {
                                loadTestIntoDraft(test)
                            }) {
                                Text("Edit")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }

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

    private func loadTestIntoDraft(_ test: LactateTest) {
        editingTest = test
        draft = LactateTestDraft(
            athleteName: test.athleteName,
            sport: test.sport,
            date: test.date,
            steps: test.steps
        )

        graphXAxis = .power
        selectedGraphPoint = nil
    }

    private func isCompared(_ test: LactateTest) -> Bool {
        comparedTestIDs.contains(test.id)
    }

    private func canAddMoreComparisons(for test: LactateTest) -> Bool {
        if comparedTestIDs.contains(test.id) { return true }
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
        draft.reset()
        editingTest = nil
        graphXAxis = .power
        selectedGraphPoint = nil
    }

    private func resetForm() {
        resetEntryFields()
        comparedTestIDs = []
    }

    private func deleteSavedTests() {
        store.clearAll()
        comparedTestIDs = []
        selectedGraphPoint = nil
        editingTest = nil
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
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd-yy"

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

        draft = LactateTestDraft(
            athleteName: athleteName,
            sport: .cycling,
            date: formatter.date(from: dateString) ?? Date(),
            steps: loadedSteps.isEmpty ? [LactateStep.emptyStep(stepIndex: 1)] : loadedSteps
        )

        editingTest = nil
        graphXAxis = .power
        selectedGraphPoint = nil
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
            thresholdHorizontalMarks
            seriesLineMarks
            seriesPointMarks
            thresholdVerticalMarks
            selectedPointMarks
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
                                guard let plotFrameAnchor = proxy.plotFrame else {
                                    return
                                }

                                let plotFrame = geometry[plotFrameAnchor]
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

    @ChartContentBuilder
    private var thresholdHorizontalMarks: some ChartContent {
        RuleMark(y: .value("LT1", 2.0))
            .foregroundStyle(.green)
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))

        RuleMark(y: .value("LT2", 4.0))
            .foregroundStyle(.red)
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
    }

    @ChartContentBuilder
    private var seriesLineMarks: some ChartContent {
        ForEach(displaySeries) { series in
            ForEach(series.points) { point in
                LineMark(
                    x: .value(graphXAxis.title, point.x),
                    y: .value("Lactate", point.lactate),
                    series: .value("Series", series.id)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(series.color)
            }
        }
    }

    @ChartContentBuilder
    private var seriesPointMarks: some ChartContent {
        ForEach(displaySeries) { series in
            ForEach(series.points) { point in
                PointMark(
                    x: .value(graphXAxis.title, point.x),
                    y: .value("Lactate", point.lactate)
                )
                .foregroundStyle(series.color)
                .symbolSize(50)
            }
        }
    }

    @ChartContentBuilder
    private var thresholdVerticalMarks: some ChartContent {
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
    }

    @ChartContentBuilder
    private var selectedPointMarks: some ChartContent {
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
                value.wrappedValue = trimmed.isEmpty ? nil : Int(trimmed)
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
                    value.wrappedValue = Double(trimmed.replacingOccurrences(of: ",", with: "."))
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

#Preview {
    ContentView(store: SwiftDataTestsStore())
}
