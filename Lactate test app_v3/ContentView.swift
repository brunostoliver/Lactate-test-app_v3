//
//  ContentView.swift
//  Lactate test app_v3
//
//  Created by Bruno Oliveira on 3/15/26.
//

import SwiftUI
import UIKit
import Charts

struct ContentView: View {
    @ObservedObject var store: SwiftDataTestsStore

    @State private var unitPreference: UnitPreference = .metric
    @AppStorage("appearanceMode") private var appearanceModeRawValue: String = AppearanceMode.system.rawValue

    @State private var draft = LactateTestDraft()

    @State private var graphXAxis: GraphXAxis = .power
    @State private var selectedGraphPoint: GraphPoint? = nil
    @State private var comparedTestIDs: [UUID] = []
    @State private var showFullScreenChart: Bool = false
    @State private var showDeleteSavedTestsAlert: Bool = false
    @State private var editingTest: LactateTest? = nil
    @State private var testPendingDeletion: LactateTest? = nil
    @State private var showDeleteSingleTestAlert: Bool = false

    @State private var shareItem: ShareItem? = nil
    @State private var exportErrorMessage: String? = nil
    @State private var showExportErrorAlert: Bool = false

    init(store: SwiftDataTestsStore) {
        self.store = store
    }

    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Color.clear
                            .frame(height: 1)
                            .id("topOfForm")

                        editingBannerSection
                        formSection

                        if hasEnoughDataForAnalysis {
                            tableSection
                        }

                        if shouldShowComparisonSection {
                            comparisonSection
                        }

                        if hasEnoughDataForAnalysis {
                            graphSection
                            thresholdsSection
                            trainingZonesSection
                        }

                        saveSection
                        savedTestsSection
                        appearanceSection
                        sampleTestsSection
                    }
                    .padding()
                }
                .navigationBarTitle("Lactate Test Intake", displayMode: .inline)
                .navigationBarItems(trailing: unitsPicker)
                .onChange(of: editingTest?.id) {
                    withAnimation {
                        proxy.scrollTo("topOfForm", anchor: .top)
                    }
                }
            }
        }
        .preferredColorScheme(appearanceMode.colorScheme)
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
        .sheet(item: $shareItem) { item in
            ShareSheet(activityItems: [item.url])
        }
        .alert("Delete all saved tests?", isPresented: $showDeleteSavedTestsAlert) {
            Button("Delete", role: .destructive) {
                deleteSavedTests()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently erase all saved lactate tests stored in the app.")
        }
        .alert("Delete this saved test?", isPresented: $showDeleteSingleTestAlert, presenting: testPendingDeletion) { test in
            Button("Delete", role: .destructive) {
                deleteSingleSavedTest(test)
            }
            Button("Cancel", role: .cancel) {
                testPendingDeletion = nil
            }
        } message: { test in
            Text("This will permanently delete \(test.athleteName) from saved tests.")
        }
        .alert("Export Failed", isPresented: $showExportErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(exportErrorMessage ?? "An unknown export error occurred.")
        }
    }

    // MARK: - Derived State

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRawValue) ?? .system
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

    private var currentGraphPoints: [GraphPoint] {
        graphPoints(for: draft.steps, seriesLabel: currentSeriesLabel, seriesColor: .blue)
    }

    private var displaySeries: [GraphSeries] {
        var series: [GraphSeries] = []

        if !currentGraphPoints.isEmpty {
            series.append(
                GraphSeries(
                    id: "current",
                    label: currentSeriesLabel,
                    color: .blue,
                    points: currentGraphPoints
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

    private var hasEnoughDataForAnalysis: Bool {
        currentGraphPoints.count >= 2
    }

    private var shouldShowComparisonSection: Bool {
        hasEnoughDataForAnalysis && !selectedComparisonTests.isEmpty
    }

    private var yAxisDomain: ClosedRange<Double> {
        let maxLactate = max(allDisplayedGraphPoints.map(\.lactate).max() ?? 6.0, 4.5)
        return 0.0...(maxLactate + 0.8)
    }

    private var xAxisDomain: ClosedRange<Double> {
        let allX = allDisplayedGraphPoints.map(\.x)
        guard let first = allX.min(), let last = allX.max() else {
            return 0.0...100.0
        }

        let lowerPadding: Double
        let upperPadding: Double

        switch graphXAxis {
        case .power:
            lowerPadding = 15.0
            upperPadding = 10.0
        case .heartRate:
            lowerPadding = 8.0
            upperPadding = 5.0
        }

        let minX = max(0.0, first - lowerPadding)
        let maxX = last + upperPadding

        if maxX <= minX {
            return minX...(minX + 1.0)
        }

        return minX...maxX
    }

    private var primaryWorkloadPoints: [WorkloadLactatePoint] {
        primaryWorkloadPoints(for: draft)
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

    private var preferredMiddleLactate: Double? {
        modifiedDmaxResult?.lactate ?? primaryDmaxLactate
    }

    private var heartRateFiveZones: FiveZoneThresholds? {
        heartRateFiveZones(for: draft)
    }

    private var powerFiveZones: FiveZoneThresholds? {
        powerFiveZones(for: draft)
    }

    private var cyclingSpeedFiveZones: FiveZoneThresholds? {
        cyclingSpeedFiveZones(for: draft)
    }

    private var runningPaceFiveZones: FiveZoneThresholds? {
        runningPaceFiveZones(for: draft)
    }

    // MARK: - CRUD / Form Actions


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

    private func saveCurrentTest() {
        if let editingTest {
            store.updateTest(editingTest, with: draft)
        } else {
            store.appendTest(draft.asLactateTest())
        }

        resetEntryFields()
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

    private func isLoaded(_ test: LactateTest) -> Bool {
        editingTest?.id == test.id
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
        testPendingDeletion = nil
        showDeleteSingleTestAlert = false
    }

    private func deleteSingleSavedTest(_ test: LactateTest) {
        if let editingTest, editingTest.id == test.id {
            resetEntryFields()
        }

        comparedTestIDs.removeAll { $0 == test.id }
        store.deleteTest(id: test.id)

        if let selectedGraphPoint, selectedGraphPoint.seriesLabel == testLabel(for: test) {
            self.selectedGraphPoint = nil
        }

        testPendingDeletion = nil
        showDeleteSingleTestAlert = false
    }

    // MARK: - Sample Tests

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

        let count = min(lactates.count, heartRates.count, powers.count)
        var loadedSteps: [LactateStep] = []

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

    // MARK: - File Helpers

    private func writeExportFile(data: Data, filename: String) throws -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(filename)

        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: fileURL)
        }

        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    private func sanitizedFilename(_ filename: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "\\/:*?\"<>|")
        let components = filename.components(separatedBy: invalidCharacters)
        return components.joined(separator: "_")
    }

    private func isoDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func timestampString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: Date())
    }

    private func optionalDoubleString(_ value: Double?, decimals: Int) -> String {
        guard let value else { return "" }
        return String(format: "%.\(decimals)f", value)
    }

    private func optionalIntString(_ value: Int?) -> String {
        guard let value else { return "" }
        return String(value)
    }

    private func csvEscape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private func stepTableHeader(for sport: Sport) -> String {
        switch sport {
        case .running:
            return "Step | Lactate | HR | Pace | Power"
        case .cycling:
            return "Step | Lactate | HR | Speed | Power"
        }
    }

    private func stepTableRow(for sport: Sport, step: LactateStep) -> String {
        let lactate = step.lactate.map { String(format: "%.2f mmol/L", $0) } ?? "-"
        let hr = step.avgHeartRate.map { "\($0) bpm" } ?? "-"
        let power = step.powerWatts.map { "\($0) W" } ?? "-"

        switch sport {
        case .running:
            let pace = step.runningPaceSecondsPerKm.map {
                PaceFormatter.string(fromSecondsPerKm: $0, unit: unitPreference)
            } ?? "-"
            return "\(step.stepIndex) | \(lactate) | \(hr) | \(pace) | \(power)"

        case .cycling:
            let speed = step.cyclingSpeedKmh.map {
                SpeedFormatter.string(fromKmh: $0, unit: unitPreference)
            } ?? "-"
            return "\(step.stepIndex) | \(lactate) | \(hr) | \(speed) | \(power)"
        }
    }

    // MARK: - Sections

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

    private var editingBannerSection: some View {
        Group {
            if let editingTest {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("Loaded")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.25))
                            .cornerRadius(6)

                        Text("Viewing loaded saved test - \(editingTest.athleteName)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    Text("You may review the values below or modify them and tap Update Test.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button("Cancel Viewing/Editing") {
                        resetEntryFields()
                    }
                    .font(.caption)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.15))
                .cornerRadius(8)
            }
        }
    }

    private var formSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(editingTest == nil ? "Test Details" : "Loaded Saved Test")
                    .font(.headline)

                Spacer()

                if let editingTest {
                    Text(shortDateString(editingTest.date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if editingTest != nil {
                Text("This saved test is loaded into the form. Tap Update Test to save any changes.")
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

            Divider()

            Text("Steps")
                .font(.headline)

            ForEach($draft.steps) { $step in
                StepEditor(
                    step: $step,
                    sport: draft.sport,
                    unitPreference: unitPreference
                )
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
                    colorName: .blue,
                    title: currentSeriesLabel,
                    subtitle: "Current input"
                )

                if selectedComparisonTests.indices.contains(0) {
                    let test = selectedComparisonTests[0]
                    comparisonLegendRow(
                        colorName: .orange,
                        title: testLabel(for: test),
                        subtitle: "Comparison 1"
                    )
                }

                if selectedComparisonTests.indices.contains(1) {
                    let test = selectedComparisonTests[1]
                    comparisonLegendRow(
                        colorName: .purple,
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

    private func comparisonLegendRow(colorName: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(colorName)
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
                    z5: "Z5 VO2max: > \(formatPower(powerZones.z4Upper))"
                )
            }

            if let hrZones = heartRateFiveZones {
                fiveZoneCardIncreasing(
                    title: "Heart Rate",
                    z1: "Z1 Recovery: < \(formatHeartRate(hrZones.z1Upper))",
                    z2: "Z2 Endurance: \(formatHeartRate(hrZones.z1Upper)) to \(formatHeartRate(hrZones.z2Upper))",
                    z3: "Z3 Tempo: \(formatHeartRate(hrZones.z2Upper)) to \(formatHeartRate(hrZones.z3Upper))",
                    z4: "Z4 Threshold: \(formatHeartRate(hrZones.z3Upper)) to \(formatHeartRate(hrZones.z4Upper))",
                    z5: "Z5 VO2max: > \(formatHeartRate(hrZones.z4Upper))"
                )
            }

            if draft.sport == .cycling, let speedZones = cyclingSpeedFiveZones {
                fiveZoneCardIncreasing(
                    title: "Speed",
                    z1: "Z1 Recovery: < \(formatSpeed(speedZones.z1Upper))",
                    z2: "Z2 Endurance: \(formatSpeed(speedZones.z1Upper)) to \(formatSpeed(speedZones.z2Upper))",
                    z3: "Z3 Tempo: \(formatSpeed(speedZones.z2Upper)) to \(formatSpeed(speedZones.z3Upper))",
                    z4: "Z4 Threshold: \(formatSpeed(speedZones.z3Upper)) to \(formatSpeed(speedZones.z4Upper))",
                    z5: "Z5 VO2max: > \(formatSpeed(speedZones.z4Upper))"
                )
            }

            if draft.sport == .running, let paceZones = runningPaceFiveZones {
                fiveZoneCardDecreasing(
                    title: "Pace",
                    z1: "Z1 Recovery: slower than \(formatPace(paceZones.z1Upper))",
                    z2: "Z2 Endurance: \(formatPace(paceZones.z1Upper)) to \(formatPace(paceZones.z2Upper))",
                    z3: "Z3 Tempo: \(formatPace(paceZones.z2Upper)) to \(formatPace(paceZones.z3Upper))",
                    z4: "Z4 Threshold: \(formatPace(paceZones.z3Upper)) to \(formatPace(paceZones.z4Upper))",
                    z5: "Z5 VO2max: faster than \(formatPace(paceZones.z4Upper))"
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

    private var savedTestsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            HStack {
                Text("Saved Tests")
                    .font(.headline)

                Spacer()

                if !store.tests.isEmpty {
                    Menu {
                        Button("Export All as JSON") {
                            exportAllSavedTestsJSON()
                        }
                        Button("Export All as CSV") {
                            exportAllSavedTestsCSV()
                        }
                        Button("Export All as PDF") {
                            exportAllSavedTestsPDF()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export All")
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                    }
                }
            }

            if store.tests.isEmpty {
                Text("No tests saved yet.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(store.tests) { test in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .center, spacing: 8) {
                            Text(test.athleteName).bold()
                            Text(test.sport.rawValue.capitalized)
                            Text(shortDateString(test.date))

                            if isLoaded(test) {
                                Text("Loaded")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.orange.opacity(0.25))
                                    .cornerRadius(6)
                            }
                        }

                        Text("Steps: \(test.steps.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack(spacing: 10) {
                            Button(action: {
                                loadTestIntoDraft(test)
                            }) {
                                Text("Load/Edit")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }

                            Menu {
                                Button("Export as JSON") {
                                    exportSingleTestJSON(test)
                                }
                                Button("Export as CSV") {
                                    exportSingleTestCSV(test)
                                }
                                Button("Export as PDF") {
                                    exportSingleTestPDF(test)
                                }
                            } label: {
                                Text("Export")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }

                            Button(action: {
                                testPendingDeletion = test
                                showDeleteSingleTestAlert = true
                            }) {
                                Text("Delete")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.red)

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
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(isLoaded(test) ? Color.orange.opacity(0.08) : Color.clear)
                    .cornerRadius(8)
                }
            }
        }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            Text("Appearance")
                .font(.headline)

            Picker("Appearance", selection: $appearanceModeRawValue) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.title).tag(mode.rawValue)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }

    private var sampleTestsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            Text("Sample Tests")
                .font(.headline)

            Text("Temporary utilities for loading example data.")
                .font(.caption)
                .foregroundColor(.secondary)

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
    }

    // MARK: - Export JSON

    private func exportSingleTestJSON(_ test: LactateTest) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601

            let data = try encoder.encode(test)
            let filename = sanitizedFilename("\(test.athleteName)_\(isoDateString(test.date))_lactate_test.json")
            let url = try writeExportFile(data: data, filename: filename)
            shareItem = ShareItem(url: url)
        } catch {
            exportErrorMessage = "Could not export this test as JSON. \(error.localizedDescription)"
            showExportErrorAlert = true
        }
    }

    private func exportAllSavedTestsJSON() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601

            let data = try encoder.encode(store.tests)
            let filename = sanitizedFilename("all_lactate_tests_\(timestampString()).json")
            let url = try writeExportFile(data: data, filename: filename)
            shareItem = ShareItem(url: url)
        } catch {
            exportErrorMessage = "Could not export all saved tests as JSON. \(error.localizedDescription)"
            showExportErrorAlert = true
        }
    }

    // MARK: - Export CSV

    private func exportSingleTestCSV(_ test: LactateTest) {
        do {
            let csv = csvString(for: test)
            guard let data = csv.data(using: .utf8) else {
                throw ExportError.encodingFailed
            }

            let filename = sanitizedFilename("\(test.athleteName)_\(isoDateString(test.date))_lactate_test.csv")
            let url = try writeExportFile(data: data, filename: filename)
            shareItem = ShareItem(url: url)
        } catch {
            exportErrorMessage = "Could not export this test as CSV. \(error.localizedDescription)"
            showExportErrorAlert = true
        }
    }

    private func exportAllSavedTestsCSV() {
        do {
            let csv = csvString(for: store.tests)
            guard let data = csv.data(using: .utf8) else {
                throw ExportError.encodingFailed
            }

            let filename = sanitizedFilename("all_lactate_tests_\(timestampString()).csv")
            let url = try writeExportFile(data: data, filename: filename)
            shareItem = ShareItem(url: url)
        } catch {
            exportErrorMessage = "Could not export all saved tests as CSV. \(error.localizedDescription)"
            showExportErrorAlert = true
        }
    }

    private func csvString(for test: LactateTest) -> String {
        csvString(for: [test])
    }

    private func csvString(for tests: [LactateTest]) -> String {
        var rows: [String] = []
        rows.append(csvHeaderRow())

        for test in tests {
            for step in test.steps.sorted(by: { $0.stepIndex < $1.stepIndex }) {
                rows.append(csvRow(for: test, step: step))
            }
        }

        return rows.joined(separator: "\n")
    }

    private func csvHeaderRow() -> String {
        [
            "athlete_name",
            "date",
            "sport",
            "step_index",
            "lactate_mmol_l",
            "avg_heart_rate_bpm",
            "running_pace_seconds_per_km",
            "running_pace_min_per_km",
            "running_pace_min_per_mile",
            "cycling_speed_kmh",
            "cycling_speed_mph",
            "power_watts"
        ]
        .joined(separator: ",")
    }

    private func csvRow(for test: LactateTest, step: LactateStep) -> String {
        let paceMetric: String
        let paceImperial: String

        if let secondsPerKm = step.runningPaceSecondsPerKm {
            paceMetric = PaceFormatter.string(fromSecondsPerKm: secondsPerKm, unit: .metric)
            paceImperial = PaceFormatter.string(fromSecondsPerKm: secondsPerKm, unit: .imperial)
        } else {
            paceMetric = ""
            paceImperial = ""
        }

        let speedMph: String
        if let kmh = step.cyclingSpeedKmh {
            speedMph = String(format: "%.2f", kmh / 1.60934)
        } else {
            speedMph = ""
        }

        let values: [String] = [
            test.athleteName,
            isoDateString(test.date),
            test.sport.rawValue,
            String(step.stepIndex),
            optionalDoubleString(step.lactate, decimals: 2),
            optionalIntString(step.avgHeartRate),
            step.runningPaceSecondsPerKm.map(String.init) ?? "",
            paceMetric,
            paceImperial,
            optionalDoubleString(step.cyclingSpeedKmh, decimals: 2),
            speedMph,
            optionalIntString(step.powerWatts)
        ]

        return values.map(csvEscape).joined(separator: ",")
    }

    // MARK: - Export PDF

    @MainActor
    private func exportSingleTestPDF(_ test: LactateTest) {
        do {
            let data = try pdfData(for: [test])
            let filename = sanitizedFilename("\(test.athleteName)_\(isoDateString(test.date))_lactate_report.pdf")
            let url = try writeExportFile(data: data, filename: filename)
            shareItem = ShareItem(url: url)
        } catch {
            exportErrorMessage = "Could not export this test as PDF. \(error.localizedDescription)"
            showExportErrorAlert = true
        }
    }

    @MainActor
    private func exportAllSavedTestsPDF() {
        do {
            let data = try pdfData(for: store.tests)
            let filename = sanitizedFilename("all_lactate_reports_\(timestampString()).pdf")
            let url = try writeExportFile(data: data, filename: filename)
            shareItem = ShareItem(url: url)
        } catch {
            exportErrorMessage = "Could not export all saved tests as PDF. \(error.localizedDescription)"
            showExportErrorAlert = true
        }
    }

    @MainActor
    private func pdfData(for tests: [LactateTest]) throws -> Data {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 40
        let contentWidth = pageWidth - (margin * 2)

        let bounds = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)

        let data = renderer.pdfData { context in
            var currentY: CGFloat = 0

            func beginNewPage() {
                context.beginPage()
                currentY = margin
            }

            func ensureSpace(_ neededHeight: CGFloat) {
                if currentY + neededHeight > pageHeight - margin {
                    beginNewPage()
                }
            }

            func drawLine(_ text: String, font: UIFont, color: UIColor = .black, spacingAfter: CGFloat = 6) {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: color
                ]

                let rect = NSString(string: text).boundingRect(
                    with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attributes,
                    context: nil
                )

                ensureSpace(rect.height + spacingAfter)
                NSString(string: text).draw(
                    in: CGRect(x: margin, y: currentY, width: contentWidth, height: rect.height),
                    withAttributes: attributes
                )
                currentY += rect.height + spacingAfter
            }

            func drawSectionHeader(_ text: String) {
                currentY += 4
                drawLine(text, font: .boldSystemFont(ofSize: 16), spacingAfter: 8)
            }

            func drawDivider() {
                ensureSpace(12)
                let path = UIBezierPath()
                path.move(to: CGPoint(x: margin, y: currentY))
                path.addLine(to: CGPoint(x: pageWidth - margin, y: currentY))
                UIColor.systemGray3.setStroke()
                path.lineWidth = 1
                path.stroke()
                currentY += 10
            }

            func drawImage(_ image: UIImage, maxHeight: CGFloat = 240) {
                let aspectRatio = image.size.width / image.size.height
                let drawWidth = contentWidth
                let drawHeight = min(maxHeight, drawWidth / aspectRatio)

                ensureSpace(drawHeight + 10)

                let rect = CGRect(x: margin, y: currentY, width: drawWidth, height: drawHeight)
                image.draw(in: rect)

                currentY += drawHeight + 10
            }

            beginNewPage()

            drawLine("Lactate Test Report", font: .boldSystemFont(ofSize: 22), spacingAfter: 12)
            drawLine("Generated: \(DateFormatter.pdfTimestamp.string(from: Date()))", font: .systemFont(ofSize: 11), color: .darkGray, spacingAfter: 14)

            for (index, test) in tests.enumerated() {
                if index > 0 {
                    drawDivider()
                }

                drawSectionHeader("Athlete")
                drawLine("Name: \(test.athleteName)", font: .systemFont(ofSize: 12))
                drawLine("Sport: \(test.sport.rawValue.capitalized)", font: .systemFont(ofSize: 12))
                drawLine("Date: \(shortDateString(test.date))", font: .systemFont(ofSize: 12), spacingAfter: 12)

                if let chartImage = exportChartImage(for: test) {
                    drawSectionHeader("Lactate Curve")
                    drawImage(chartImage)
                }

                drawSectionHeader("Steps")
                drawLine(stepTableHeader(for: test.sport), font: .boldSystemFont(ofSize: 11), spacingAfter: 4)

                for step in test.steps.sorted(by: { $0.stepIndex < $1.stepIndex }) {
                    drawLine(stepTableRow(for: test.sport, step: step), font: .systemFont(ofSize: 10), spacingAfter: 3)
                }

                currentY += 8

                let analysis = analysisSummary(for: test)

                drawSectionHeader("Threshold Summary")
                for line in analysis.thresholdLines {
                    drawLine(line, font: .systemFont(ofSize: 12), spacingAfter: 4)
                }

                currentY += 8
                drawSectionHeader("Training Zones")
                for line in analysis.zoneLines {
                    drawLine(line, font: .systemFont(ofSize: 12), spacingAfter: 4)
                }

                currentY += 10
            }
        }

        return data
    }

    @MainActor
    private func exportChartImage(for test: LactateTest) -> UIImage? {
        let points = graphPointsForExport(test)
        guard points.count >= 2 else { return nil }

        let yMax = max(points.map(\.lactate).max() ?? 6.0, 4.5)
        let yDomain = 0.0...(yMax + 0.8)

        let xValues = points.map(\.x)
        guard let minX = xValues.min(), let maxX = xValues.max() else { return nil }

        let xDomain = max(0.0, minX - 15.0)...(maxX + 10.0)

        let chartView = ExportLactateChartView(
            points: points,
            yAxisDomain: yDomain,
            xAxisDomain: xDomain,
            lt1Point: interpolatedThresholdPoint(targetLactate: 2.0, points: points),
            dmaxPoint: {
                guard let dmaxLactate = dmaxPoint(from: primaryWorkloadPoints(for: test))?.lactate else { return nil }
                return interpolatedThresholdPoint(targetLactate: dmaxLactate, points: points)
            }(),
            lt2Point: interpolatedThresholdPoint(targetLactate: 4.0, points: points),
            title: "\(test.athleteName) - Lactate Curve"
        )
        .frame(width: 700, height: 380)
        .background(Color.white)

        let renderer = ImageRenderer(content: chartView)
        renderer.scale = 2.0
        return renderer.uiImage
    }

    private func analysisSummary(for test: LactateTest) -> ExportAnalysisSummary {
        let graphPoints = graphPointsForExport(test)

        let lt1 = interpolatedThresholdPoint(targetLactate: 2.0, points: graphPoints)
        let dmaxLactate = dmaxPoint(from: primaryWorkloadPoints(for: test))?.lactate
        let dmax = dmaxLactate.flatMap { interpolatedThresholdPoint(targetLactate: $0, points: graphPoints) }
        let modifiedDmax = modifiedDmaxPoint(from: primaryWorkloadPoints(for: test))
        let logLog = logLogBreakpoint(from: primaryWorkloadPoints(for: test))
        let lt2 = interpolatedThresholdPoint(targetLactate: 4.0, points: graphPoints)

        var thresholdLines: [String] = []

        if let lt1 {
            thresholdLines.append("LT1 (2.0 mmol/L): \(formatExportXAxisValue(lt1.x))")
        } else {
            thresholdLines.append("LT1 (2.0 mmol/L): not reached")
        }

        if let dmaxLactate, let dmax {
            thresholdLines.append("Dmax: \(formatExportXAxisValue(dmax.x)) at lactate \(String(format: "%.2f", dmaxLactate)) mmol/L")
        } else {
            thresholdLines.append("Dmax: not enough data")
        }

        if let modifiedDmax {
            thresholdLines.append("Modified Dmax (Newell): \(formatPrimaryWorkload(modifiedDmax.workload, for: test)) at lactate \(String(format: "%.2f", modifiedDmax.lactate)) mmol/L")
        } else {
            thresholdLines.append("Modified Dmax (Newell): not enough data")
        }

        if let logLog {
            thresholdLines.append("Log-log breakpoint: \(formatPrimaryWorkload(logLog.workload, for: test)) at lactate \(String(format: "%.2f", logLog.lactate)) mmol/L")
        } else {
            thresholdLines.append("Log-log breakpoint: not enough data")
        }

        if let lt2 {
            thresholdLines.append("LT2 (4.0 mmol/L): \(formatExportXAxisValue(lt2.x))")
        } else {
            thresholdLines.append("LT2 (4.0 mmol/L): not reached")
        }

        return ExportAnalysisSummary(
            thresholdLines: thresholdLines,
            zoneLines: exportTrainingZoneLines(for: test)
        )
    }

    private func graphPointsForExport(_ test: LactateTest) -> [GraphPoint] {
        test.steps.compactMap { step in
            guard let lactate = step.lactate, let power = step.powerWatts else { return nil }
            return GraphPoint(
                stepIndex: step.stepIndex,
                x: Double(power),
                lactate: lactate,
                heartRate: step.avgHeartRate,
                power: power,
                seriesLabel: test.athleteName,
                seriesColor: .blue
            )
        }
        .sorted { $0.x < $1.x }
    }

    private func primaryWorkloadPoints(for test: LactateTest) -> [WorkloadLactatePoint] {
        switch test.sport {
        case .cycling:
            let powerPoints = test.steps.compactMap { step -> WorkloadLactatePoint? in
                guard let power = step.powerWatts, let lactate = step.lactate else { return nil }
                return WorkloadLactatePoint(workload: Double(power), lactate: lactate)
            }
            .sorted { $0.workload < $1.workload }

            if powerPoints.count >= 3 { return powerPoints }

            let speedPoints = test.steps.compactMap { step -> WorkloadLactatePoint? in
                guard let speed = step.cyclingSpeedKmh, let lactate = step.lactate else { return nil }
                return WorkloadLactatePoint(workload: speed, lactate: lactate)
            }
            .sorted { $0.workload < $1.workload }

            if speedPoints.count >= 3 { return speedPoints }

            return test.steps.compactMap { step -> WorkloadLactatePoint? in
                guard let hr = step.avgHeartRate, let lactate = step.lactate else { return nil }
                return WorkloadLactatePoint(workload: Double(hr), lactate: lactate)
            }
            .sorted { $0.workload < $1.workload }

        case .running:
            let paceSpeedPoints = test.steps.compactMap { step -> WorkloadLactatePoint? in
                guard let paceSeconds = step.runningPaceSecondsPerKm,
                      let lactate = step.lactate,
                      paceSeconds > 0 else { return nil }
                let speedKmh = 3600.0 / Double(paceSeconds)
                return WorkloadLactatePoint(workload: speedKmh, lactate: lactate)
            }
            .sorted { $0.workload < $1.workload }

            if paceSpeedPoints.count >= 3 { return paceSpeedPoints }

            let powerPoints = test.steps.compactMap { step -> WorkloadLactatePoint? in
                guard let power = step.powerWatts, let lactate = step.lactate else { return nil }
                return WorkloadLactatePoint(workload: Double(power), lactate: lactate)
            }
            .sorted { $0.workload < $1.workload }

            if powerPoints.count >= 3 { return powerPoints }

            return test.steps.compactMap { step -> WorkloadLactatePoint? in
                guard let hr = step.avgHeartRate, let lactate = step.lactate else { return nil }
                return WorkloadLactatePoint(workload: Double(hr), lactate: lactate)
            }
            .sorted { $0.workload < $1.workload }
        }
    }

    private func exportTrainingZoneLines(for test: LactateTest) -> [String] {
        var lines: [String] = []

        if let powerZones = powerFiveZones(for: test) {
            lines.append("Power")
            lines.append("  Z1 Recovery: < \(formatPower(powerZones.z1Upper))")
            lines.append("  Z2 Endurance: \(formatPower(powerZones.z1Upper)) to \(formatPower(powerZones.z2Upper))")
            lines.append("  Z3 Tempo: \(formatPower(powerZones.z2Upper)) to \(formatPower(powerZones.z3Upper))")
            lines.append("  Z4 Threshold: \(formatPower(powerZones.z3Upper)) to \(formatPower(powerZones.z4Upper))")
            lines.append("  Z5 VO2max: > \(formatPower(powerZones.z4Upper))")
        }

        if let hrZones = heartRateFiveZones(for: test) {
            lines.append("Heart Rate")
            lines.append("  Z1 Recovery: < \(formatHeartRate(hrZones.z1Upper))")
            lines.append("  Z2 Endurance: \(formatHeartRate(hrZones.z1Upper)) to \(formatHeartRate(hrZones.z2Upper))")
            lines.append("  Z3 Tempo: \(formatHeartRate(hrZones.z2Upper)) to \(formatHeartRate(hrZones.z3Upper))")
            lines.append("  Z4 Threshold: \(formatHeartRate(hrZones.z3Upper)) to \(formatHeartRate(hrZones.z4Upper))")
            lines.append("  Z5 VO2max: > \(formatHeartRate(hrZones.z4Upper))")
        }

        if test.sport == .cycling, let speedZones = cyclingSpeedFiveZones(for: test) {
            lines.append("Speed")
            lines.append("  Z1 Recovery: < \(formatSpeed(speedZones.z1Upper))")
            lines.append("  Z2 Endurance: \(formatSpeed(speedZones.z1Upper)) to \(formatSpeed(speedZones.z2Upper))")
            lines.append("  Z3 Tempo: \(formatSpeed(speedZones.z2Upper)) to \(formatSpeed(speedZones.z3Upper))")
            lines.append("  Z4 Threshold: \(formatSpeed(speedZones.z3Upper)) to \(formatSpeed(speedZones.z4Upper))")
            lines.append("  Z5 VO2max: > \(formatSpeed(speedZones.z4Upper))")
        }

        if test.sport == .running, let paceZones = runningPaceFiveZones(for: test) {
            lines.append("Pace")
            lines.append("  Z1 Recovery: slower than \(formatPace(paceZones.z1Upper))")
            lines.append("  Z2 Endurance: \(formatPace(paceZones.z1Upper)) to \(formatPace(paceZones.z2Upper))")
            lines.append("  Z3 Tempo: \(formatPace(paceZones.z2Upper)) to \(formatPace(paceZones.z3Upper))")
            lines.append("  Z4 Threshold: \(formatPace(paceZones.z3Upper)) to \(formatPace(paceZones.z4Upper))")
            lines.append("  Z5 VO2max: faster than \(formatPace(paceZones.z4Upper))")
        }

        if lines.isEmpty {
            lines.append("Not enough data to calculate training zones.")
        }

        return lines
    }

    // MARK: - Zone Helpers for Export

    private func heartRateFiveZones(for test: LactateTest) -> FiveZoneThresholds? {
        let pairs = test.steps.compactMap { step -> MetricLactatePair? in
            guard let hr = step.avgHeartRate, let lactate = step.lactate else { return nil }
            return MetricLactatePair(metric: Double(hr), lactate: lactate)
        }
        let middle = modifiedDmaxPoint(from: primaryWorkloadPoints(for: test))?.lactate ?? dmaxPoint(from: primaryWorkloadPoints(for: test))?.lactate
        return fiveZonesIncreasing(from: pairs, middleLactate: middle)
    }

    private func powerFiveZones(for test: LactateTest) -> FiveZoneThresholds? {
        let pairs = test.steps.compactMap { step -> MetricLactatePair? in
            guard let power = step.powerWatts, let lactate = step.lactate else { return nil }
            return MetricLactatePair(metric: Double(power), lactate: lactate)
        }
        let middle = modifiedDmaxPoint(from: primaryWorkloadPoints(for: test))?.lactate ?? dmaxPoint(from: primaryWorkloadPoints(for: test))?.lactate
        return fiveZonesIncreasing(from: pairs, middleLactate: middle)
    }

    private func cyclingSpeedFiveZones(for test: LactateTest) -> FiveZoneThresholds? {
        let pairs = test.steps.compactMap { step -> MetricLactatePair? in
            guard let speed = step.cyclingSpeedKmh, let lactate = step.lactate else { return nil }
            return MetricLactatePair(metric: speed, lactate: lactate)
        }
        let middle = modifiedDmaxPoint(from: primaryWorkloadPoints(for: test))?.lactate ?? dmaxPoint(from: primaryWorkloadPoints(for: test))?.lactate
        return fiveZonesIncreasing(from: pairs, middleLactate: middle)
    }

    private func runningPaceFiveZones(for test: LactateTest) -> FiveZoneThresholds? {
        let pairs = test.steps.compactMap { step -> MetricLactatePair? in
            guard let paceSeconds = step.runningPaceSecondsPerKm,
                  let lactate = step.lactate,
                  paceSeconds > 0 else { return nil }
            let speedKmh = 3600.0 / Double(paceSeconds)
            return MetricLactatePair(metric: speedKmh, lactate: lactate)
        }

        let middle = modifiedDmaxPoint(from: primaryWorkloadPoints(for: test))?.lactate ?? dmaxPoint(from: primaryWorkloadPoints(for: test))?.lactate
        guard let speedZones = fiveZonesIncreasing(from: pairs, middleLactate: middle) else { return nil }

        return FiveZoneThresholds(
            z1Upper: 3600.0 / speedZones.z1Upper,
            z2Upper: 3600.0 / speedZones.z2Upper,
            z3Upper: 3600.0 / speedZones.z3Upper,
            z4Upper: 3600.0 / speedZones.z4Upper
        )
    }


    private func graphPoints(for testSteps: [LactateStep], seriesLabel: String, seriesColor: Color) -> [GraphPoint] {
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

    private func nearestPoint(toX xValue: Double) -> GraphPoint? {
        guard !allDisplayedGraphPoints.isEmpty else { return nil }
        return allDisplayedGraphPoints.min { abs($0.x - xValue) < abs($1.x - xValue) }
    }

    private func interpolatedThresholdPoint(targetLactate: Double) -> ThresholdPoint? {
        interpolatedThresholdPoint(targetLactate: targetLactate, points: currentGraphPoints)
    }

    private func interpolatedThresholdPoint(targetLactate: Double, points: [GraphPoint]) -> ThresholdPoint? {
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

    private func primaryWorkloadPoints(for draft: LactateTestDraft) -> [WorkloadLactatePoint] {
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

    private func heartRateFiveZones(for draft: LactateTestDraft) -> FiveZoneThresholds? {
        let pairs = draft.steps.compactMap { step -> MetricLactatePair? in
            guard let hr = step.avgHeartRate, let lactate = step.lactate else { return nil }
            return MetricLactatePair(metric: Double(hr), lactate: lactate)
        }
        return fiveZonesIncreasing(from: pairs, middleLactate: preferredMiddleLactate)
    }

    private func powerFiveZones(for draft: LactateTestDraft) -> FiveZoneThresholds? {
        let pairs = draft.steps.compactMap { step -> MetricLactatePair? in
            guard let power = step.powerWatts, let lactate = step.lactate else { return nil }
            return MetricLactatePair(metric: Double(power), lactate: lactate)
        }
        return fiveZonesIncreasing(from: pairs, middleLactate: preferredMiddleLactate)
    }

    private func cyclingSpeedFiveZones(for draft: LactateTestDraft) -> FiveZoneThresholds? {
        let pairs = draft.steps.compactMap { step -> MetricLactatePair? in
            guard let speed = step.cyclingSpeedKmh, let lactate = step.lactate else { return nil }
            return MetricLactatePair(metric: speed, lactate: lactate)
        }
        return fiveZonesIncreasing(from: pairs, middleLactate: preferredMiddleLactate)
    }

    private func runningPaceFiveZones(for draft: LactateTestDraft) -> FiveZoneThresholds? {
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


    // MARK: - Formatting

    private func formatXAxisValue(_ value: Double) -> String {
        switch graphXAxis {
        case .power:
            return "\(Int(value.rounded())) W"
        case .heartRate:
            return "\(Int(value.rounded())) bpm"
        }
    }

    private func formatExportXAxisValue(_ value: Double) -> String {
        "\(Int(value.rounded())) W"
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

    private func formatPrimaryWorkload(_ value: Double) -> String {
        switch draft.sport {
        case .cycling:
            if draft.steps.contains(where: { $0.powerWatts != nil && $0.lactate != nil }) {
                return formatPower(value)
            }
            if draft.steps.contains(where: { $0.cyclingSpeedKmh != nil && $0.lactate != nil }) {
                return formatSpeed(value)
            }
            return formatHeartRate(value)

        case .running:
            if draft.steps.contains(where: { $0.runningPaceSecondsPerKm != nil && $0.lactate != nil }) {
                return formatSpeed(value)
            }
            if draft.steps.contains(where: { $0.powerWatts != nil && $0.lactate != nil }) {
                return formatPower(value)
            }
            return formatHeartRate(value)
        }
    }

    private func formatPrimaryWorkload(_ value: Double, for test: LactateTest) -> String {
        switch test.sport {
        case .cycling:
            if test.steps.contains(where: { $0.powerWatts != nil && $0.lactate != nil }) {
                return formatPower(value)
            }
            if test.steps.contains(where: { $0.cyclingSpeedKmh != nil && $0.lactate != nil }) {
                return formatSpeed(value)
            }
            return formatHeartRate(value)

        case .running:
            if test.steps.contains(where: { $0.runningPaceSecondsPerKm != nil && $0.lactate != nil }) {
                return formatSpeed(value)
            }
            if test.steps.contains(where: { $0.powerWatts != nil && $0.lactate != nil }) {
                return formatPower(value)
            }
            return formatHeartRate(value)
        }
    }

    private func shortDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func testLabel(for test: LactateTest) -> String {
        "\(test.athleteName) (\(shortDateString(test.date)))"
    }

}


struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

extension DateFormatter {
    static var pdfTimestamp: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
}

#Preview {
    ContentView(store: SwiftDataTestsStore())
}



