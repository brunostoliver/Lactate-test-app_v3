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

struct AthleteDetailWorkspaceView: View {
    @ObservedObject var store: SwiftDataTestsStore
    let athlete: Athlete

    @State private var editorDestination: ContentView.EditorDestination?
    @State private var comparisonDestination: ContentView.ComparisonDestination?

    var body: some View {
        HStack(spacing: 0) {
            ContentView(
                store: store,
                selectedAthlete: athlete,
                showsNavigationChrome: false,
                externalEditorDestination: $editorDestination,
                externalComparisonDestination: $comparisonDestination
            )
            .frame(minWidth: 320, idealWidth: 420, maxWidth: 500)

            Divider()

            detailPane
                .frame(minWidth: 340, maxWidth: .infinity)
        }
        .navigationTitle(athlete.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var detailPane: some View {
        if let editorDestination {
            NavigationStack {
                ContentView(
                    store: store,
                    selectedAthlete: athlete,
                    showsNavigationChrome: false,
                    screenMode: .editor,
                    initialEditingTest: editorDestination.test,
                    externalEditorDestination: $editorDestination
                )
                .id(editorDestination.id)
                .navigationTitle(editorDestination.test == nil ? "New Test" : "View/Edit")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            self.editorDestination = nil
                        }
                    }
                }
            }
        } else if let comparisonDestination,
                  let baseTest = store.tests(for: athlete.id).first(where: { $0.id == comparisonDestination.baseTestID }) {
            NavigationStack {
                ContentView(
                    store: store,
                    selectedAthlete: athlete,
                    showsNavigationChrome: false,
                    screenMode: .workspace,
                    initialEditingTest: baseTest,
                    externalComparisonDestination: $comparisonDestination,
                    initialLoadedTestMode: .comparisonBase,
                    initialComparedTestIDs: comparisonDestination.comparedTestIDs
                )
                .id(comparisonDestination.id)
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
        } else {
            VStack(spacing: 12) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 36))
                    .foregroundColor(.secondary)
                Text("Select or Create a Test")
                    .font(.headline)
                Text("Use New Test or View/Edit from the left pane to open the editor here.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
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
    @State private var splitViewVisibility: NavigationSplitViewVisibility = .all

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
        NavigationSplitView(columnVisibility: $splitViewVisibility) {
            sidebarColumn
        } content: {
            contentColumn
        } detail: {
            detailColumn
        }
        .navigationSplitViewStyle(.balanced)
        .preferredColorScheme(appearanceMode.colorScheme)
        .onAppear {
            if selectedAthleteID == nil {
                selectedAthleteID = store.athletes.first?.id
            }
            splitViewVisibility = .all
        }
        .onChange(of: selectedAthleteID) {
            editorDestination = nil
            comparisonDestination = nil
        }
        .onChange(of: editorDestination?.id) {
            if editorDestination != nil {
                splitViewVisibility = .all
            }
        }
        .onChange(of: comparisonDestination?.id) {
            if comparisonDestination != nil {
                splitViewVisibility = .all
            }
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
            .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 260)
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
            .navigationSplitViewColumnWidth(min: 360, ideal: 460, max: 560)
        } else {
            placeholderColumn(
                systemImage: "person.2",
                title: "Select an Athlete",
                message: "Choose an athlete from the list to view tests and analysis."
            )
            .navigationSplitViewColumnWidth(min: 360, ideal: 460, max: 560)
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        if let athlete = selectedAthlete, let editorDestination {
            editorDetailColumn(for: athlete, destination: editorDestination)
                .navigationSplitViewColumnWidth(min: 420, ideal: 560, max: 720)
        } else if let athlete = selectedAthlete,
                  let comparisonDestination,
                  let baseTest = store.tests(for: athlete.id).first(where: { $0.id == comparisonDestination.baseTestID }) {
            comparisonDetailColumn(for: athlete, destination: comparisonDestination, baseTest: baseTest)
                .navigationSplitViewColumnWidth(min: 420, ideal: 560, max: 720)
        } else {
            placeholderColumn(
                systemImage: "square.and.pencil",
                title: "Select or Create a Test",
                message: "Use New Test or View/Edit from the middle pane to open the editor here."
            )
            .navigationSplitViewColumnWidth(min: 420, ideal: 560, max: 720)
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
            .id(destination.id)
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
            .id(destination.id)
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


