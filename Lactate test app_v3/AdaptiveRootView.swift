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
            .navigationTitle("Athletes")
            .sheet(isPresented: $showNewAthleteSheet) {
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
        } detail: {
            if let athlete = selectedAthlete {
                ContentView(
                    store: store,
                    selectedAthlete: athlete,
                    showsNavigationChrome: false
                )
                .navigationTitle(athlete.name)
                .navigationBarTitleDisplayMode(.inline)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "person.2")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("Select an Athlete")
                        .font(.headline)
                    Text("Choose an athlete from the list to view tests and analysis.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
        }
        .preferredColorScheme(appearanceMode.colorScheme)
        .onAppear {
            if selectedAthleteID == nil {
                selectedAthleteID = store.athletes.first?.id
            }
        }
        .onChange(of: store.athletes.map(\.id)) {
            if let selectedAthleteID,
               store.athletes.contains(where: { $0.id == selectedAthleteID }) {
                return
            }
            self.selectedAthleteID = store.athletes.first?.id
        }
    }
}

