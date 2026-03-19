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
    }

    func resetForm() {
        resetEntryFields()
        comparedTestIDs = []
    }

    func deleteSavedTests() {
        store.clearAll()
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

    // MARK: - Export JSON

    func exportSingleTestJSON(_ test: LactateTest) {
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

    func exportAllSavedTestsJSON() {
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

    func exportSingleTestCSV(_ test: LactateTest) {
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

    func exportAllSavedTestsCSV() {
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

    func csvString(for test: LactateTest) -> String {
        csvString(for: [test])
    }

    func csvString(for tests: [LactateTest]) -> String {
        var rows: [String] = []
        rows.append(csvHeaderRow())

        for test in tests {
            for step in test.steps.sorted(by: { $0.stepIndex < $1.stepIndex }) {
                rows.append(csvRow(for: test, step: step))
            }
        }

        return rows.joined(separator: "\n")
    }

    func csvHeaderRow() -> String {
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

    func csvRow(for test: LactateTest, step: LactateStep) -> String {
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
    func exportSingleTestPDF(_ test: LactateTest) {
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
    func exportAllSavedTestsPDF() {
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
    func pdfData(for tests: [LactateTest]) throws -> Data {
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
    func exportChartImage(for test: LactateTest) -> UIImage? {
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

    func analysisSummary(for test: LactateTest) -> ExportAnalysisSummary {
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

    func graphPointsForExport(_ test: LactateTest) -> [GraphPoint] {
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

    func primaryWorkloadPoints(for test: LactateTest) -> [WorkloadLactatePoint] {
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

    func exportTrainingZoneLines(for test: LactateTest) -> [String] {
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

    func heartRateFiveZones(for test: LactateTest) -> FiveZoneThresholds? {
        let pairs = test.steps.compactMap { step -> MetricLactatePair? in
            guard let hr = step.avgHeartRate, let lactate = step.lactate else { return nil }
            return MetricLactatePair(metric: Double(hr), lactate: lactate)
        }
        let middle = modifiedDmaxPoint(from: primaryWorkloadPoints(for: test))?.lactate ?? dmaxPoint(from: primaryWorkloadPoints(for: test))?.lactate
        return fiveZonesIncreasing(from: pairs, middleLactate: middle)
    }

    func powerFiveZones(for test: LactateTest) -> FiveZoneThresholds? {
        let pairs = test.steps.compactMap { step -> MetricLactatePair? in
            guard let power = step.powerWatts, let lactate = step.lactate else { return nil }
            return MetricLactatePair(metric: Double(power), lactate: lactate)
        }
        let middle = modifiedDmaxPoint(from: primaryWorkloadPoints(for: test))?.lactate ?? dmaxPoint(from: primaryWorkloadPoints(for: test))?.lactate
        return fiveZonesIncreasing(from: pairs, middleLactate: middle)
    }

    func cyclingSpeedFiveZones(for test: LactateTest) -> FiveZoneThresholds? {
        let pairs = test.steps.compactMap { step -> MetricLactatePair? in
            guard let speed = step.cyclingSpeedKmh, let lactate = step.lactate else { return nil }
            return MetricLactatePair(metric: speed, lactate: lactate)
        }
        let middle = modifiedDmaxPoint(from: primaryWorkloadPoints(for: test))?.lactate ?? dmaxPoint(from: primaryWorkloadPoints(for: test))?.lactate
        return fiveZonesIncreasing(from: pairs, middleLactate: middle)
    }

    func runningPaceFiveZones(for test: LactateTest) -> FiveZoneThresholds? {
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

    // MARK: - Formatting

    func formatXAxisValue(_ value: Double) -> String {
        switch graphXAxis {
        case .power:
            return "\(Int(value.rounded())) W"
        case .heartRate:
            return "\(Int(value.rounded())) bpm"
        }
    }

    func formatExportXAxisValue(_ value: Double) -> String {
        "\(Int(value.rounded())) W"
    }

    func formatHeartRate(_ value: Double) -> String {
        "\(Int(value.rounded())) bpm"
    }

    func formatPower(_ value: Double) -> String {
        "\(Int(value.rounded())) W"
    }

    func formatSpeed(_ value: Double) -> String {
        SpeedFormatter.string(fromKmh: value, unit: unitPreference)
    }

    func formatPace(_ value: Double) -> String {
        PaceFormatter.string(fromSecondsPerKm: Int(value.rounded()), unit: unitPreference)
    }

    func formatPrimaryWorkload(_ value: Double) -> String {
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

    func formatPrimaryWorkload(_ value: Double, for test: LactateTest) -> String {
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

    func shortDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    func testLabel(for test: LactateTest) -> String {
        "\(test.athleteName) (\(shortDateString(test.date)))"
    }

}

#Preview {
    ContentView(store: SwiftDataTestsStore())
}





