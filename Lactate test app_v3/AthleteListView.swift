import SwiftUI

struct AthleteListView: View {
    @ObservedObject var store: SwiftDataTestsStore

    @AppStorage("appearanceMode") private var appearanceModeRawValue: String = AppearanceMode.system.rawValue
    @AppStorage("unitPreference") private var unitPreferenceRawValue: String = UnitPreference.metric.rawValue

    @State private var newAthleteName = ""
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
        NavigationStack {
            List {
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
                            NavigationLink {
                                ContentView(
                                    store: store,
                                    selectedAthlete: athlete,
                                    showsNavigationChrome: false
                                )
                                .navigationTitle(athlete.name)
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                        .accessibilityLabel("App logo")
                }
            }
            .preferredColorScheme(appearanceMode.colorScheme)
            .sheet(isPresented: $showNewAthleteSheet) {
                NavigationStack {
                    Form {
                        Section("New Athlete") {
                            TextField("Athlete name", text: $newAthleteName)
                        }
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
                                store.appendAthlete(name: trimmedName)
                                selectedAthleteForNewTest = store.athletes.first { $0.name == trimmedName }
                                showNewAthleteSheet = false
                            }
                            .disabled(newAthleteName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
            }
            .navigationDestination(item: $selectedAthleteForNewTest) { athlete in
                ContentView(
                    store: store,
                    selectedAthlete: athlete,
                    showsNavigationChrome: false
                )
                .navigationTitle(athlete.name)
            }
        }
    }
}


