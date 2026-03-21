import SwiftUI

struct AdaptiveRootView: View {
    @ObservedObject var store: SwiftDataTestsStore

    var body: some View {
        GeometryReader { geometry in
            if shouldUseWideIPadLayout(for: geometry.size) {
                AthleteSplitView(store: store)
            } else {
                AthleteListView(store: store)
            }
        }
    }

    private func shouldUseWideIPadLayout(for size: CGSize) -> Bool {
        UIDevice.current.userInterfaceIdiom == .pad &&
        size.width > size.height &&
        size.width >= 1000
    }
}

private struct AthleteSplitView: View {
    @ObservedObject var store: SwiftDataTestsStore

    @AppStorage("appearanceMode") private var appearanceModeRawValue: String = AppearanceMode.system.rawValue
    @AppStorage("unitPreference") private var unitPreferenceRawValue: String = UnitPreference.metric.rawValue

    @State private var newAthleteName = ""
    @State private var showNewAthleteSheet = false
    @State private var selectedAthleteID: UUID?
    @State private var editorDestination: ContentView.EditorDestination?
    @State private var comparisonDestination: ContentView.ComparisonDestination?

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRawValue) ?? .system
    }

    private var unitPreference: UnitPreference {
        get { UnitPreference(rawValue: unitPreferenceRawValue) ?? .metric }
        nonmutating set { unitPreferenceRawValue = newValue.rawValue }
    }

    private var selectedAthlete: Athlete? {
        guard let selectedAthleteID else { return nil }
        return store.athletes.first { $0.id == selectedAthleteID }
    }

    private var unitPreferenceBinding: Binding<UnitPreference> {
        Binding(
            get: { unitPreference },
            set: { unitPreference = $0 }
        )
    }

    var body: some View {
        NavigationSplitView {
            sidebarColumn
        } content: {
            contentColumn
        } detail: {
            detailColumn
        }
        .preferredColorScheme(appearanceMode.colorScheme)
        .onAppear {
            if selectedAthleteID == nil {
                selectedAthleteID = store.athletes.first?.id
            }
        }
        .onChange(of: selectedAthleteID) {
            editorDestination = nil
            comparisonDestination = nil
        }
        .onChange(of: store.athletes.map(\.id)) {
            if let selectedAthleteID,
               store.athletes.contains(where: { $0.id == selectedAthleteID }) {
                return
            }
            self.selectedAthleteID = store.athletes.first?.id
            editorDestination = nil
            comparisonDestination = nil
        }
    }

    private var sidebarColumn: some View {
        athleteList
            .navigationTitle("Athletes")
            .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 340)
            .sheet(isPresented: $showNewAthleteSheet) {
                newAthleteSheet
            }
    }

    @ViewBuilder
    private var contentColumn: some View {
        if let athlete = selectedAthlete {
            ContentView(
                store: store,
                selectedAthlete: athlete,
                showsNavigationChrome: false,
                externalEditorDestination: $editorDestination,
                externalComparisonDestination: $comparisonDestination
            )
            .navigationTitle(athlete.name)
            .navigationBarTitleDisplayMode(.inline)
            .navigationSplitViewColumnWidth(min: 480, ideal: 620, max: 760)
        } else {
            placeholderColumn(
                systemImage: "person.2",
                title: "Select an Athlete",
                message: "Choose an athlete from the list to view tests and analysis."
            )
            .navigationSplitViewColumnWidth(min: 480, ideal: 620, max: 760)
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        if let athlete = selectedAthlete, let editorDestination {
            editorDetailColumn(for: athlete, destination: editorDestination)
                .navigationSplitViewColumnWidth(min: 420, ideal: 520, max: 640)
        } else if let athlete = selectedAthlete,
                  let comparisonDestination,
                  let baseTest = store.tests(for: athlete.id).first(where: { $0.id == comparisonDestination.baseTestID }) {
            comparisonDetailColumn(for: athlete, destination: comparisonDestination, baseTest: baseTest)
                .navigationSplitViewColumnWidth(min: 420, ideal: 520, max: 640)
        } else {
            placeholderColumn(
                systemImage: "square.and.pencil",
                title: "Select or Create a Test",
                message: "Use New Test or View/Edit from the middle pane to open the editor here."
            )
            .navigationSplitViewColumnWidth(min: 420, ideal: 520, max: 640)
        }
    }

    private var athleteList: some View {
        List(selection: $selectedAthleteID) {
            Section {
                Button {
                    newAthleteName = ""
                    showNewAthleteSheet = true
                } label: {
                    Label("New Athlete", systemImage: "person.badge.plus")
                }
            }

            Section("Select Existing Athlete") {
                if store.athletes.isEmpty {
                    Text("No athletes yet. Create a new athlete to begin.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(store.athletes) { athlete in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(athlete.name)
                            Text("\(store.tests(for: athlete.id).count) tests")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .tag(athlete.id)
                    }
                }
            }

            Section("Appearance") {
                Picker("Appearance", selection: $appearanceModeRawValue) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Units") {
                Picker("Units", selection: unitPreferenceBinding) {
                    ForEach(UnitPreference.allCases) { unit in
                        Text(unit.title).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var newAthleteSheet: some View {
        NavigationStack {
            HStack {
                Spacer(minLength: 0)

                Form {
                    Section("New Athlete") {
                        TextField("Athlete name", text: $newAthleteName)
                    }
                }
                .frame(maxWidth: 560)

                Spacer(minLength: 0)
            }
            .navigationTitle("New Athlete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showNewAthleteSheet = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let trimmedName = newAthleteName.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let athlete = store.appendAthlete(name: trimmedName) {
                            selectedAthleteID = athlete.id
                        }
                        showNewAthleteSheet = false
                    }
                    .disabled(newAthleteName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func editorDetailColumn(for athlete: Athlete, destination: ContentView.EditorDestination) -> some View {
        NavigationStack {
            ContentView(
                store: store,
                selectedAthlete: athlete,
                showsNavigationChrome: false,
                screenMode: .editor,
                initialEditingTest: destination.test,
                externalEditorDestination: $editorDestination
            )
            .navigationTitle(destination.test == nil ? "New Test" : "View/Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        self.editorDestination = nil
                    }
                }
            }
        }
    }

    private func comparisonDetailColumn(
        for athlete: Athlete,
        destination: ContentView.ComparisonDestination,
        baseTest: LactateTest
    ) -> some View {
        NavigationStack {
            ContentView(
                store: store,
                selectedAthlete: athlete,
                showsNavigationChrome: false,
                screenMode: .workspace,
                initialEditingTest: baseTest,
                externalComparisonDestination: $comparisonDestination,
                initialLoadedTestMode: .comparisonBase,
                initialComparedTestIDs: destination.comparedTestIDs
            )
            .navigationTitle("Compare")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        self.comparisonDestination = nil
                    }
                }
            }
        }
    }

    private func placeholderColumn(systemImage: String, title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}


