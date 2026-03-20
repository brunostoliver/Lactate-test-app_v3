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
    let selectedAthlete: Athlete?
    let showsNavigationChrome: Bool

    @State var unitPreference: UnitPreference = .metric
    @AppStorage("appearanceMode") var appearanceModeRawValue: String = AppearanceMode.system.rawValue

    @State var draft = LactateTestDraft()

    @State var graphXAxis: GraphXAxis = .power
    @State var selectedGraphPoint: GraphPoint? = nil
    @State var comparedTestIDs: [UUID] = []
    @State var showFullScreenChart: Bool = false
    @State var showDeleteSavedTestsAlert: Bool = false
    @State var editingTest: LactateTest? = nil
    @State var testPendingDeletion: LactateTest? = nil
    @State var showDeleteSingleTestAlert: Bool = false

    @State var shareItem: ShareItem? = nil
    @State var exportErrorMessage: String? = nil
    @State var showExportErrorAlert: Bool = false
    @State var didApplySelectedAthlete = false

    init(
        store: SwiftDataTestsStore,
        selectedAthlete: Athlete? = nil,
        showsNavigationChrome: Bool = true
    ) {
        self.store = store
        self.selectedAthlete = selectedAthlete
        self.showsNavigationChrome = showsNavigationChrome
    }

    var body: some View {
        Group {
            if showsNavigationChrome {
                NavigationView {
                    editorScrollView
                        .navigationBarTitle(navigationTitle, displayMode: .inline)
                        .navigationBarItems(trailing: unitsPicker)
                }
            } else {
                editorScrollView
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
        .alert(deleteSavedTestsAlertTitle, isPresented: $showDeleteSavedTestsAlert) {
            Button("Delete", role: .destructive) {
                deleteSavedTests()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(deleteSavedTestsAlertMessage)
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
        .onAppear {
            applySelectedAthleteIfNeeded()
        }
    }

    // MARK: - Derived State

    var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRawValue) ?? .system
    }

    var currentSeriesLabel: String {
        let trimmed = draft.athleteName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Current Input"
        }
        return "\(trimmed) (\(shortDateString(draft.date)))"
    }

    var navigationTitle: String {
        selectedAthlete?.name ?? "Lactate Test Intake"
    }

    var displayedTests: [LactateTest] {
        guard let selectedAthlete else { return store.tests }
        return store.tests(for: selectedAthlete.id)
    }

    var deleteSavedTestsAlertTitle: String {
        if selectedAthlete != nil {
            return "Delete this athlete's saved tests?"
        }
        return "Delete all saved tests?"
    }

    var deleteSavedTestsAlertMessage: String {
        if let selectedAthlete {
            return "This will permanently erase all saved lactate tests for \(selectedAthlete.name)."
        }
        return "This will permanently erase all saved lactate tests stored in the app."
    }

    @ViewBuilder
    var editorScrollView: some View {
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
                    sampleTestsSection
                }
                .padding()
            }
            .onChange(of: editingTest?.id) {
                withAnimation {
                    proxy.scrollTo("topOfForm", anchor: .top)
                }
            }
        }
    }

    var selectedComparisonTests: [LactateTest] {
        store.tests
            .filter { comparedTestIDs.contains($0.id) }
            .sorted { lhs, rhs in
                (comparedTestIDs.firstIndex(of: lhs.id) ?? 0) < (comparedTestIDs.firstIndex(of: rhs.id) ?? 0)
            }
    }

    var currentGraphPoints: [GraphPoint] {
        graphPoints(for: draft.steps, seriesLabel: currentSeriesLabel, seriesColor: .blue)
    }

    var displaySeries: [GraphSeries] {
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

    var allDisplayedGraphPoints: [GraphPoint] {
        displaySeries.flatMap { $0.points }
    }

    var hasEnoughDataForAnalysis: Bool {
        currentGraphPoints.count >= 2
    }

    var shouldShowComparisonSection: Bool {
        hasEnoughDataForAnalysis && !selectedComparisonTests.isEmpty
    }

    var yAxisDomain: ClosedRange<Double> {
        let maxLactate = max(allDisplayedGraphPoints.map(\.lactate).max() ?? 6.0, 4.5)
        return 0.0...(maxLactate + 0.8)
    }

    var xAxisDomain: ClosedRange<Double> {
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

    var primaryWorkloadPoints: [WorkloadLactatePoint] {
        primaryWorkloadPoints(for: draft)
    }

    var primaryDmaxLactate: Double? {
        dmaxPoint(from: primaryWorkloadPoints)?.lactate
    }

    var dmaxDisplayPoint: ThresholdPoint? {
        guard let dmaxLactate = primaryDmaxLactate else { return nil }
        return interpolatedThresholdPoint(targetLactate: dmaxLactate)
    }

    var modifiedDmaxResult: WorkloadThresholdResult? {
        modifiedDmaxPoint(from: primaryWorkloadPoints)
    }

    var logLogBreakpointResult: WorkloadThresholdResult? {
        logLogBreakpoint(from: primaryWorkloadPoints)
    }

    var preferredMiddleLactate: Double? {
        modifiedDmaxResult?.lactate ?? primaryDmaxLactate
    }

    var heartRateFiveZones: FiveZoneThresholds? {
        heartRateFiveZones(for: draft)
    }

    var powerFiveZones: FiveZoneThresholds? {
        powerFiveZones(for: draft)
    }

    var cyclingSpeedFiveZones: FiveZoneThresholds? {
        cyclingSpeedFiveZones(for: draft)
    }

    var runningPaceFiveZones: FiveZoneThresholds? {
        runningPaceFiveZones(for: draft)
    }

    // MARK: - CRUD / Form Actions


    func addStep() {
        let nextIndex = (draft.steps.map { $0.stepIndex }.max() ?? 0) + 1
        draft.steps.append(LactateStep.emptyStep(stepIndex: nextIndex))
    }

    func removeLastStep() {
        _ = draft.steps.popLast()
        if draft.steps.isEmpty {
            draft.steps = [LactateStep.emptyStep(stepIndex: 1)]
        }
        selectedGraphPoint = nil
    }

    func saveCurrentTest() {
        if let editingTest {
            store.updateTest(editingTest, with: draft)
        } else {
            store.appendTest(draft.asLactateTest())
        }

        resetEntryFields()
    }

    func loadTestIntoDraft(_ test: LactateTest) {
        editingTest = test
        draft = LactateTestDraft(
            athleteID: test.athleteID,
            athleteName: test.athleteName,
            sport: test.sport,
            date: test.date,
            steps: test.steps
        )
        graphXAxis = .power
        selectedGraphPoint = nil
    }

    func isLoaded(_ test: LactateTest) -> Bool {
        editingTest?.id == test.id
    }

    func isCompared(_ test: LactateTest) -> Bool {
        comparedTestIDs.contains(test.id)
    }

    func canAddMoreComparisons(for test: LactateTest) -> Bool {
        if comparedTestIDs.contains(test.id) { return true }
        return comparedTestIDs.count < 2
    }

    func addComparedTest(_ test: LactateTest) {
        guard !comparedTestIDs.contains(test.id) else { return }
        guard comparedTestIDs.count < 2 else { return }
        comparedTestIDs.append(test.id)
        selectedGraphPoint = nil
    }

    func removeComparedTest(_ test: LactateTest) {
        comparedTestIDs.removeAll { $0 == test.id }
        selectedGraphPoint = nil
    }

    func resetEntryFields() {
        draft.reset()
        editingTest = nil
        graphXAxis = .power
        selectedGraphPoint = nil
        applySelectedAthlete(force: true)
    }

    func resetForm() {
        resetEntryFields()
        comparedTestIDs = []
    }

    func deleteSavedTests() {
        if selectedAthlete != nil {
            for test in displayedTests {
                store.deleteTest(id: test.id)
            }
        } else {
            store.clearAll()
        }
        comparedTestIDs = []
        selectedGraphPoint = nil
        editingTest = nil
        testPendingDeletion = nil
        showDeleteSingleTestAlert = false
    }

    func deleteSingleSavedTest(_ test: LactateTest) {
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

    func loadSampleTest1() {
        loadCyclingSample(
            athleteName: "Sample Test 1",
            dateString: "04-29-23",
            lactates: [1.7, 1.3, 1.9, 2.4, 3.4, 7.1],
            heartRates: [114, 124, 127, 133, 138, 147],
            powers: [127, 124, 142, 162, 183, 204]
        )
    }

    func loadSampleTest2() {
        loadCyclingSample(
            athleteName: "Sample Test 2",
            dateString: "04-04-23",
            lactates: [1.6, 1.7, 1.8, 3.2, 3.7, 7.2],
            heartRates: [107, 112, 119, 129, 132, 141],
            powers: [118, 122, 143, 163, 183, 209]
        )
    }

    func loadSampleTest3() {
        loadCyclingSample(
            athleteName: "Sample Test 3",
            dateString: "02-25-23",
            lactates: [1.9, 1.7, 2.6, 3.8, 5.6],
            heartRates: [115, 119, 127, 136, 141],
            powers: [125, 122, 143, 164, 183]
        )
    }

    func loadCyclingSample(
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

        let targetAthleteID = selectedAthlete?.id
        let targetAthleteName = selectedAthlete?.name ?? athleteName

        draft = LactateTestDraft(
            athleteID: targetAthleteID,
            athleteName: targetAthleteName,
            sport: .cycling,
            date: formatter.date(from: dateString) ?? Date(),
            steps: loadedSteps.isEmpty ? [LactateStep.emptyStep(stepIndex: 1)] : loadedSteps
        )

        editingTest = nil
        graphXAxis = .power
        selectedGraphPoint = nil
    }

    // MARK: - File Helpers

    func writeExportFile(data: Data, filename: String) throws -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(filename)

        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: fileURL)
        }

        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    func sanitizedFilename(_ filename: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "\\/:*?\"<>|")
        let components = filename.components(separatedBy: invalidCharacters)
        return components.joined(separator: "_")
    }

    func isoDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    func timestampString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: Date())
    }

    func optionalDoubleString(_ value: Double?, decimals: Int) -> String {
        guard let value else { return "" }
        return String(format: "%.\(decimals)f", value)
    }

    func optionalIntString(_ value: Int?) -> String {
        guard let value else { return "" }
        return String(value)
    }

    func csvEscape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    func stepTableHeader(for sport: Sport) -> String {
        switch sport {
        case .running:
            return "Step | Lactate | HR | Pace | Power"
        case .cycling:
            return "Step | Lactate | HR | Speed | Power"
        }
    }

    func stepTableRow(for sport: Sport, step: LactateStep) -> String {
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

    func applySelectedAthleteIfNeeded() {
        guard !didApplySelectedAthlete else { return }
        didApplySelectedAthlete = true
        applySelectedAthlete(force: true)
    }

    func applySelectedAthlete(force: Bool = false) {
        guard let selectedAthlete else { return }
        if force || draft.athleteName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draft.athleteID = selectedAthlete.id
            draft.athleteName = selectedAthlete.name
        }
    }

}

#Preview {
    ContentView(store: SwiftDataTestsStore())
}





