import SwiftUI

struct AthleteListView: View {
    @ObservedObject var store: SwiftDataTestsStore

    @AppStorage("appearanceMode") private var appearanceModeRawValue: String = AppearanceMode.system.rawValue
    @AppStorage("unitPreference") private var unitPreferenceRawValue: String = UnitPreference.metric.rawValue

    @State private var newAthleteName = ""
    @State private var newAthleteDateOfBirth: Date?
    @State private var newAthleteGender: AthleteGender?
    @State private var showNewAthleteSheet = false
    @State private var selectedAthleteForNewTest: Athlete?

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRawValue) ?? .system
    }

    private var unitPreference: UnitPreference {
        get { UnitPreference(rawValue: unitPreferenceRawValue) ?? .metric }
        nonmutating set { unitPreferenceRawValue = newValue.rawValue }
    }

    private var unitPreferenceBinding: Binding<UnitPreference> {
        Binding(
            get: { unitPreference },
            set: { unitPreference = $0 }
        )
    }

    var body: some View {
        GeometryReader { geometry in
            NavigationStack {
                List {
                    Section {
                        Button {
                            newAthleteName = ""
                            newAthleteDateOfBirth = nil
                            newAthleteGender = nil
                            showNewAthleteSheet = true
                        } label: {
                            Label("New Athlete", systemImage: "person.badge.plus")
                        }

                        Button {
                            store.reload()
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    }

                    Section("Select Existing Athlete") {
                        if store.athletes.isEmpty {
                            Text("No athletes yet. Create a new athlete to begin.")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(store.athletes) { athlete in
                                NavigationLink {
                                    athleteDestination(for: athlete, size: geometry.size)
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(athlete.name)
                                        Text("\(store.tests(for: athlete.id).count) tests")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
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
                .preferredColorScheme(appearanceMode.colorScheme)
                .sheet(isPresented: $showNewAthleteSheet) {
                    AthleteProfileEditorView(
                        title: "New Athlete",
                        confirmationTitle: "Create",
                        name: $newAthleteName,
                        dateOfBirth: $newAthleteDateOfBirth,
                        gender: $newAthleteGender,
                        onSave: {
                            let trimmedName = newAthleteName.trimmingCharacters(in: .whitespacesAndNewlines)
                            if let athlete = store.appendAthlete(
                                name: trimmedName,
                                dateOfBirth: newAthleteDateOfBirth,
                                gender: newAthleteGender
                            ) {
                                selectedAthleteForNewTest = athlete
                            }
                            showNewAthleteSheet = false
                        },
                        onCancel: {
                            showNewAthleteSheet = false
                        }
                    )
                }
                .navigationDestination(item: $selectedAthleteForNewTest) { athlete in
                    athleteDestination(for: athlete, size: geometry.size)
                }
            }
        }
    }

    @ViewBuilder
    private func athleteDestination(for athlete: Athlete, size: CGSize) -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            AthleteDetailWorkspaceView(store: store, athlete: athlete)
        } else {
            ContentView(
                store: store,
                selectedAthlete: athlete,
                showsNavigationChrome: false
            )
            .navigationTitle(athlete.name)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}


