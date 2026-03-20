import SwiftUI

struct AthleteListView: View {
    @ObservedObject var store: SwiftDataTestsStore

    @State private var newAthleteName = ""
    @State private var showNewAthleteSheet = false
    @State private var selectedAthleteForNewTest: Athlete?

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
            }
            .navigationTitle("Athletes")
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

