import SwiftUI

extension ContentView {
    // MARK: - Sections

    var editingBannerSection: some View {
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

    var formSection: some View {
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

            if let selectedAthlete {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Athlete")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(selectedAthlete.name)
                        .font(.body)
                        .fontWeight(.semibold)
                }
            } else {
                TextField("Athlete name", text: $draft.athleteName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

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

            HStack(spacing: 10) {
                Button(action: addStep) {
                    Label("Add Step", systemImage: "plus")
                }
                .buttonStyle(SecondaryActionButtonStyle())

                if !draft.steps.isEmpty {
                    Button(action: removeLastStep) {
                        Label("Remove Last Step", systemImage: "minus")
                    }
                    .buttonStyle(DestructiveActionButtonStyle())
                }
            }
        }
    }

    var tableSection: some View {
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

    var comparisonSection: some View {
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

    func comparisonLegendRow(colorName: Color, title: String, subtitle: String) -> some View {
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

    var graphSection: some View {
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

    var thresholdsSection: some View {
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

    var trainingZonesSection: some View {
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

    func fiveZoneCardIncreasing(
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

    func fiveZoneCardDecreasing(
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

    var saveSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Button(action: saveCurrentTest) {
                        Label(editingTest == nil ? "Save Test" : "Update Test", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(FilledActionButtonStyle())
                    .disabled(
                        draft.athleteName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        draft.steps.isEmpty
                    )

                    Button(action: resetForm) {
                        Label(editingTest == nil ? "Reset Form" : "Cancel Edit", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }

            }
        }
    }

    var savedTestsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            HStack {
                Text("Saved Tests")
                    .font(.headline)

                Spacer()

                if !displayedTests.isEmpty {
                    Menu {
                        Button("Export All as JSON") {
                            exportAllSavedTestsJSON(displayedTests)
                        }
                        Button("Export All as CSV") {
                            exportAllSavedTestsCSV(displayedTests)
                        }
                        Button("Export All as PDF") {
                            exportAllSavedTestsPDF(displayedTests)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export All")
                        }
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }
            }

            if displayedTests.isEmpty {
                Text("No tests saved yet.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(displayedTests) { test in
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

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Button(action: {
                                    loadTestIntoDraft(test)
                                }) {
                                    Label("Load/Edit", systemImage: "square.and.pencil")
                                }
                                .buttonStyle(SecondaryActionButtonStyle())

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
                                    Label("Export", systemImage: "square.and.arrow.up")
                                }
                                .buttonStyle(SecondaryActionButtonStyle())

                                Button(action: {
                                    testPendingDeletion = test
                                    showDeleteSingleTestAlert = true
                                }) {
                                    Label("Delete", systemImage: "trash")
                                }
                                .buttonStyle(DestructiveActionButtonStyle())
                            }

                            HStack(spacing: 8) {
                                if isCompared(test) {
                                    Button(action: {
                                        removeComparedTest(test)
                                    }) {
                                        Label("Remove Comparison", systemImage: "minus.circle")
                                    }
                                    .buttonStyle(DestructiveActionButtonStyle())
                                } else {
                                    Button(action: {
                                        addComparedTest(test)
                                    }) {
                                        Label("Compare", systemImage: "chart.line.uptrend.xyaxis")
                                    }
                                    .buttonStyle(SecondaryActionButtonStyle())
                                    .disabled(!canAddMoreComparisons(for: test))
                                }
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

    var sampleTestsSection: some View {
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
}

struct FilledActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .fontWeight(.semibold)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 38)
            .background(Color.accentColor.opacity(configuration.isPressed ? 0.7 : 1.0))
            .foregroundColor(.white)
            .clipShape(Capsule())
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .fontWeight(.semibold)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 38)
            .background(Color(.secondarySystemBackground).opacity(configuration.isPressed ? 0.7 : 1.0))
            .foregroundColor(.primary)
            .overlay(
                Capsule()
                    .stroke(Color(.separator), lineWidth: 1)
            )
            .clipShape(Capsule())
    }
}

struct DestructiveActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .fontWeight(.semibold)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 38)
            .background(Color.red.opacity(configuration.isPressed ? 0.16 : 0.1))
            .foregroundColor(.red)
            .overlay(
                Capsule()
                    .stroke(Color.red.opacity(0.35), lineWidth: 1)
            )
            .clipShape(Capsule())
    }
}


