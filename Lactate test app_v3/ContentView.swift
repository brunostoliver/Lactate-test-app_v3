//
//  ContentView.swift
//  Lactate test app_v3
//
//  Created by Bruno Oliveira on 3/15/26.
//

import SwiftUI
import UIKit
import Charts

private struct SavedTestsTopPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ScrollViewResolver: UIViewRepresentable {
    let onResolve: (UIScrollView) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            if let scrollView = view.enclosingScrollView() {
                onResolve(scrollView)
            }
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            if let scrollView = uiView.enclosingScrollView() {
                onResolve(scrollView)
            }
        }
    }
}

private extension UIView {
    func enclosingScrollView() -> UIScrollView? {
        var candidate = superview
        while let view = candidate {
            if let scrollView = view as? UIScrollView {
                return scrollView
            }
            candidate = view.superview
        }
        return nil
    }
}

struct ContentView: View {
    enum ScrollTarget {
        case top
        case savedTests
    }

    enum ScreenMode {
        case detail
        case editor
    }

    enum LoadedTestMode {
        case editing
        case comparisonBase
    }

    enum ActiveFilterDatePicker: Identifiable {
        case start
        case end

        var id: String {
            switch self {
            case .start:
                return "start"
            case .end:
                return "end"
            }
        }
    }

    struct EditorDestination: Identifiable {
        let id = UUID()
        let test: LactateTest?
    }

    @ObservedObject var store: SwiftDataTestsStore
    let selectedAthlete: Athlete?
    let showsNavigationChrome: Bool
    let screenMode: ScreenMode

    @Environment(\.dismiss) private var dismiss

    @AppStorage("unitPreference") var unitPreferenceRawValue: String = UnitPreference.metric.rawValue
    @AppStorage("appearanceMode") var appearanceModeRawValue: String = AppearanceMode.system.rawValue

    @State var draft = LactateTestDraft()

    @State var graphXAxis: GraphXAxis = .power
    @State var selectedGraphPoint: GraphPoint? = nil
    @State var comparedTestIDs: [UUID] = []
    @State var showFullScreenChart: Bool = false
    @State var editingTest: LactateTest? = nil
    @State var loadedTestMode: LoadedTestMode? = nil
    @State var testSportFilter: TestSportFilter = .all
    @State var startDateFilter: Date? = nil
    @State var endDateFilter: Date? = nil
    @State var activeFilterDatePicker: ActiveFilterDatePicker? = nil
    @State var testPendingDeletion: LactateTest? = nil
    @State var showDeleteSingleTestAlert: Bool = false
    @State var showDeleteAthleteAlert: Bool = false

    @State var shareItem: ShareItem? = nil
    @State var exportErrorMessage: String? = nil
    @State var showExportErrorAlert: Bool = false
    @State var showComparisonSportMismatchAlert: Bool = false
    @State var showRestingLactateInfoAlert: Bool = false
    @State var activeThresholdInfoTopic: ThresholdInfoTopic? = nil
    @State var didApplySelectedAthlete = false
    @State var pendingScrollTarget: ScrollTarget? = .top
    @State var savedTestsSectionTop: CGFloat = 0
    @State var savedTestsSectionTopBeforePreserving: CGFloat? = nil
    @State var shouldPreserveSavedTestsViewport = false
    @State var scrollView: UIScrollView? = nil
    @State var editorDestination: EditorDestination? = nil
    @State var showSampleTestPicker: Bool = false

    init(
        store: SwiftDataTestsStore,
        selectedAthlete: Athlete? = nil,
        showsNavigationChrome: Bool = true,
        screenMode: ScreenMode = .detail,
        initialEditingTest: LactateTest? = nil
    ) {
        self.store = store
        self.selectedAthlete = selectedAthlete
        self.showsNavigationChrome = showsNavigationChrome
        self.screenMode = screenMode
        _draft = State(
            initialValue: initialEditingTest.map {
                LactateTestDraft(
                    athleteID: $0.athleteID,
                    athleteName: $0.athleteName,
                    testName: $0.resolvedTestName,
                    restingLactate: $0.restingLactate,
                    temperatureCelsius: $0.temperatureCelsius,
                    temperatureUnit: $0.temperatureUnit,
                    humidityPercent: $0.humidityPercent,
                    terrain: $0.terrain ?? "",
                    notes: $0.notes ?? "",
                    sport: $0.sport,
                    date: $0.date,
                    steps: $0.steps
                )
            } ?? LactateTestDraft()
        )
        _editingTest = State(initialValue: initialEditingTest)
        _loadedTestMode = State(initialValue: initialEditingTest == nil ? nil : .editing)
    }

    var body: some View {
        mainContent
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
        .alert("Delete this saved test?", isPresented: $showDeleteSingleTestAlert, presenting: testPendingDeletion) { test in
            Button("Delete", role: .destructive) {
                deleteSingleSavedTest(test)
            }
            Button("Cancel", role: .cancel) {
                testPendingDeletion = nil
            }
        } message: { test in
            Text("This will permanently delete \(test.resolvedTestName) from saved tests.")
        }
        .alert("Delete this athlete?", isPresented: $showDeleteAthleteAlert) {
            Button("Delete", role: .destructive) {
                deleteSelectedAthlete()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete the athlete and all associated tests.")
        }
        .alert("Export Failed", isPresented: $showExportErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(exportErrorMessage ?? "An unknown export error occurred.")
        }
        .alert("Cannot Compare Different Sports", isPresented: $showComparisonSportMismatchAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Choose tests from the same sport to compare. Running and cycling tests cannot be compared together.")
        }
        .alert("Resting Lactate", isPresented: $showRestingLactateInfoAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This value is stored with the test but excluded from graph and threshold calculations.")
        }
        .alert(item: $activeThresholdInfoTopic) { topic in
            Alert(
                title: Text(topic.title),
                message: Text(topic.message),
                dismissButton: .cancel(Text("OK"))
            )
        }
        .sheet(item: $editorDestination) { destination in
            NavigationStack {
                ContentView(
                    store: store,
                    selectedAthlete: selectedAthlete,
                    showsNavigationChrome: false,
                    screenMode: .editor,
                    initialEditingTest: destination.test
                )
                .navigationTitle(destination.test == nil ? "New Test" : "View/Edit")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            editorDestination = nil
                        }
                    }
                }
            }
        }
        .sheet(item: $activeFilterDatePicker) { picker in
            NavigationStack {
                VStack {
                    DatePicker(
                        picker == .start ? "Start Date" : "End Date",
                        selection: Binding(
                            get: {
                                switch picker {
                                case .start:
                                    return startDateFilter ?? Date()
                                case .end:
                                    return endDateFilter ?? Date()
                                }
                            },
                            set: { newValue in
                                switch picker {
                                case .start:
                                    startDateFilter = newValue
                                case .end:
                                    endDateFilter = newValue
                                }
                                DispatchQueue.main.async {
                                    activeFilterDatePicker = nil
                                }
                            }
                        ),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .padding()

                    Button("Done") {
                        activeFilterDatePicker = nil
                    }
                    .buttonStyle(FilledActionButtonStyle())
                    .padding(.bottom)
                }
                .navigationTitle(picker == .start ? "Start Date" : "End Date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            activeFilterDatePicker = nil
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showSampleTestPicker) {
            SampleTestPickerView(
                onSelect: { sample in
                    loadSampleTest(sample)
                },
                onLoadAll: {
                    loadAllSampleTests()
                }
            )
        }
        .onAppear {
            applySelectedAthleteIfNeeded()
        }
    }

    @ViewBuilder
    var mainContent: some View {
        if showsNavigationChrome {
            NavigationView {
                editorScrollView
                    .navigationBarTitle(navigationTitle, displayMode: .inline)
            }
        } else {
            editorScrollView
        }
    }

    // MARK: - Derived State

    var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRawValue) ?? .system
    }

    var unitPreference: UnitPreference {
        UnitPreference(rawValue: unitPreferenceRawValue) ?? .metric
    }

    var currentSeriesLabel: String {
        draft.resolvedTestName
    }

    var navigationTitle: String {
        selectedAthlete?.name ?? "Lactate Test Intake"
    }

    var displayedTests: [LactateTest] {
        guard let selectedAthlete else { return store.tests }
        return store.tests(for: selectedAthlete.id)
    }

    var filteredDisplayedTests: [LactateTest] {
        displayedTests.filter { test in
            let matchesSport = testSportFilter.sport.map { test.sport == $0 } ?? true
            let matchesStartDate = startDateFilter.map {
                test.date >= Calendar.current.startOfDay(for: $0)
            } ?? true

            let matchesEndDate = endDateFilter.map { endDate in
                let endOfSelectedDay = Calendar.current.date(
                    byAdding: DateComponents(day: 1, second: -1),
                    to: Calendar.current.startOfDay(for: endDate)
                ) ?? endDate
                return test.date <= endOfSelectedDay
            } ?? true

            return matchesSport && matchesStartDate && matchesEndDate
        }
    }

    var hasActiveTestFilters: Bool {
        testSportFilter != .all || startDateFilter != nil || endDateFilter != nil
    }

    var isEditorScreen: Bool {
        screenMode == .editor
    }

    @ViewBuilder
    var editorScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Color.clear
                        .frame(height: 1)
                        .id("topOfForm")

                    if !isEditorScreen {
                        enterNewTestSection
                        savedTestsSection
                            .id("savedTestsSection")
                            .background(
                                GeometryReader { geometry in
                                    Color.clear.preference(
                                        key: SavedTestsTopPreferenceKey.self,
                                        value: geometry.frame(in: .named("editorScroll")).minY
                                    )
                                }
                            )
                        deleteAthleteSection
                    }

                    if isEditorScreen && editingTest != nil {
                        analyzedTestSection
                    }

                    if isEditorScreen && editingTest != nil && hasEnoughDataForAnalysis {
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

                    if isEditorScreen {
                        formSection
                    }

                    if isEditorScreen && editingTest == nil && hasEnoughDataForAnalysis {
                        tableSection
                    }

                    if isEditorScreen {
                        saveSection
                        if editingTest == nil {
                            sampleTestsSection
                        }
                    }
                }
                .padding()
            }
            .coordinateSpace(name: "editorScroll")
            .background(
                ScrollViewResolver { resolvedScrollView in
                    scrollView = resolvedScrollView
                }
            )
            .onPreferenceChange(SavedTestsTopPreferenceKey.self) { newTop in
                let previousTop = savedTestsSectionTop
                savedTestsSectionTop = newTop

                guard shouldPreserveSavedTestsViewport,
                      let beforeTop = savedTestsSectionTopBeforePreserving,
                      let scrollView else {
                    return
                }

                let delta = newTop - beforeTop
                if abs(delta) > 0.5 {
                    DispatchQueue.main.async {
                        scrollView.setContentOffset(
                            CGPoint(x: scrollView.contentOffset.x, y: scrollView.contentOffset.y + delta),
                            animated: false
                        )
                    }
                }

                shouldPreserveSavedTestsViewport = false
                savedTestsSectionTopBeforePreserving = nil

                if previousTop == 0 {
                    savedTestsSectionTop = newTop
                }
            }
            .onChange(of: editingTest?.id) {
                switch pendingScrollTarget {
                case .top:
                    withAnimation {
                        proxy.scrollTo("topOfForm", anchor: .top)
                    }
                case .savedTests:
                    withAnimation {
                        proxy.scrollTo("savedTestsSection", anchor: .top)
                    }
                case nil:
                    break
                }
                pendingScrollTarget = .top
            }
        }
    }

    var selectedComparisonTests: [LactateTest] {
        filteredDisplayedTests
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

        if isEditorScreen {
            dismiss()
        }
        resetEntryFields()
    }

    func loadTestIntoDraft(
        _ test: LactateTest,
        scrollTarget: ScrollTarget? = .top,
        mode: LoadedTestMode = .editing
    ) {
        pendingScrollTarget = scrollTarget
        editingTest = test
        loadedTestMode = mode
        comparedTestIDs.removeAll { $0 == test.id }
        draft = LactateTestDraft(
            athleteID: test.athleteID,
            athleteName: test.athleteName,
            testName: test.resolvedTestName,
            restingLactate: test.restingLactate,
            temperatureCelsius: test.temperatureCelsius,
            temperatureUnit: test.temperatureUnit,
            humidityPercent: test.humidityPercent,
            terrain: test.terrain ?? "",
            notes: test.notes ?? "",
            sport: test.sport,
            date: test.date,
            steps: test.steps
        )
        graphXAxis = .power
        selectedGraphPoint = nil
    }

    func isLoaded(_ test: LactateTest) -> Bool {
        editingTest?.id == test.id && loadedTestMode == .editing
    }

    func isComparisonBase(_ test: LactateTest) -> Bool {
        editingTest?.id == test.id && loadedTestMode == .comparisonBase
    }

    func isCompared(_ test: LactateTest) -> Bool {
        comparedTestIDs.contains(test.id)
    }

    var comparisonBaseSport: Sport? {
        editingTest?.sport
    }

    func hasMismatchedComparisonSport(_ test: LactateTest) -> Bool {
        if let comparisonBaseSport {
            return test.sport != comparisonBaseSport
        }
        return false
    }

    func canAddMoreComparisons(for test: LactateTest) -> Bool {
        if isLoaded(test) || isComparisonBase(test) { return false }
        if comparedTestIDs.contains(test.id) { return true }
        return comparedTestIDs.count < 2
    }

    func isCompareActionDisabled(for test: LactateTest) -> Bool {
        if isLoaded(test) || isComparisonBase(test) { return true }
        if comparedTestIDs.contains(test.id) { return false }
        return comparedTestIDs.count >= 2
    }

    func addComparedTest(_ test: LactateTest) {
        savedTestsSectionTopBeforePreserving = savedTestsSectionTop
        shouldPreserveSavedTestsViewport = true

        if editingTest == nil {
            pendingScrollTarget = nil
            loadTestIntoDraft(test, scrollTarget: nil, mode: .comparisonBase)
            return
        }

        guard test.sport == draft.sport else {
            showComparisonSportMismatchAlert = true
            return
        }
        guard !isLoaded(test) else { return }
        guard !comparedTestIDs.contains(test.id) else { return }
        guard comparedTestIDs.count < 2 else { return }
        comparedTestIDs.append(test.id)
        selectedGraphPoint = nil
    }

    func removeComparedTest(_ test: LactateTest) {
        if isComparisonBase(test) {
            if let nextBaseID = comparedTestIDs.first,
               let nextBaseTest = displayedTests.first(where: { $0.id == nextBaseID }) {
                pendingScrollTarget = nil
                loadTestIntoDraft(nextBaseTest, scrollTarget: nil, mode: .comparisonBase)
            } else {
                resetEntryFields()
            }
            selectedGraphPoint = nil
            return
        }

        comparedTestIDs.removeAll { $0 == test.id }
        selectedGraphPoint = nil
    }

    func resetEntryFields() {
        draft.reset()
        editingTest = nil
        loadedTestMode = nil
        graphXAxis = .power
        selectedGraphPoint = nil
        applySelectedAthlete(force: true)
    }

    func resetForm() {
        if isEditorScreen && editingTest != nil {
            cancelEditingSession()
            return
        }

        resetEntryFields()
        comparedTestIDs = []
    }

    func cancelEditingSession() {
        resetEntryFields()
        comparedTestIDs = []

        if isEditorScreen {
            dismiss()
        }
    }

    func clearTestFilters() {
        testSportFilter = .all
        startDateFilter = nil
        endDateFilter = nil
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

    func deleteSelectedAthlete() {
        guard let selectedAthlete else { return }
        store.deleteAthlete(id: selectedAthlete.id)
        dismiss()
    }

    // MARK: - Sample Tests

    func loadSampleTest(_ sample: SampleTestTemplate) {
        draft = sampleDraft(from: sample)

        editingTest = nil
        loadedTestMode = nil
        graphXAxis = .power
        selectedGraphPoint = nil
    }

    func loadAllSampleTests() {
        for sample in SampleTestCatalog.all {
            store.appendTest(sampleDraft(from: sample).asLactateTest())
        }
    }

    func sampleDraft(from sample: SampleTestTemplate) -> LactateTestDraft {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let loadedSteps = sample.steps.enumerated().map { index, step in
            LactateStep(
                stepIndex: index + 1,
                lactate: step.lactate,
                avgHeartRate: step.avgHeartRate,
                runningPaceSecondsPerKm: parseRunningPace(step.runningPace),
                cyclingSpeedKmh: nil,
                powerWatts: step.power
            )
        }

        let targetAthleteID = selectedAthlete?.id
        let targetAthleteName = selectedAthlete?.name ?? "Untitled Athlete"

        return LactateTestDraft(
            athleteID: targetAthleteID,
            athleteName: targetAthleteName,
            sport: sample.sport,
            date: formatter.date(from: sample.dateString) ?? Date(),
            steps: loadedSteps.isEmpty ? [LactateStep.emptyStep(stepIndex: 1)] : loadedSteps
        )
    }

    func parseRunningPace(_ value: String?) -> Int? {
        guard let value else { return nil }
        let parts = value.split(separator: ":")
        guard parts.count == 2,
              let minutes = Int(parts[0]),
              let seconds = Int(parts[1]) else {
            return nil
        }
        return (minutes * 60) + seconds
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

    func temperatureStringBinding() -> Binding<String> {
        Binding(
            get: {
                guard let celsius = draft.temperatureCelsius else { return "" }

                let displayedValue: Double
                switch draft.temperatureUnit {
                case .celsius:
                    displayedValue = celsius
                case .fahrenheit:
                    displayedValue = (celsius * 9.0 / 5.0) + 32.0
                }

                return String(format: "%.1f", displayedValue)
            },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)

                guard !trimmed.isEmpty else {
                    draft.temperatureCelsius = nil
                    return
                }

                guard let enteredValue = Double(trimmed.replacingOccurrences(of: ",", with: ".")) else {
                    draft.temperatureCelsius = nil
                    return
                }

                switch draft.temperatureUnit {
                case .celsius:
                    draft.temperatureCelsius = enteredValue
                case .fahrenheit:
                    draft.temperatureCelsius = (enteredValue - 32.0) * 5.0 / 9.0
                }
            }
        )
    }

    func restingLactateStringBinding() -> Binding<String> {
        Binding(
            get: {
                guard let restingLactate = draft.restingLactate else { return "" }
                return String(format: "%.2f", restingLactate)
            },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)

                guard !trimmed.isEmpty else {
                    draft.restingLactate = nil
                    return
                }

                guard let enteredValue = Double(trimmed.replacingOccurrences(of: ",", with: ".")) else {
                    draft.restingLactate = nil
                    return
                }

                draft.restingLactate = max(0.0, enteredValue)
            }
        )
    }

    func humidityStringBinding() -> Binding<String> {
        Binding(
            get: {
                guard let humidity = draft.humidityPercent else { return "" }
                return String(format: "%.0f", humidity)
            },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)

                guard !trimmed.isEmpty else {
                    draft.humidityPercent = nil
                    return
                }

                guard let enteredValue = Double(trimmed.replacingOccurrences(of: ",", with: ".")) else {
                    draft.humidityPercent = nil
                    return
                }

                draft.humidityPercent = max(0.0, min(100.0, enteredValue))
            }
        )
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




	
