import SwiftUI

struct AthleteProfileEditorView: View {
    let title: String
    let confirmationTitle: String
    @Binding var name: String
    @Binding var dateOfBirth: Date?
    @Binding var gender: AthleteGender?
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Athlete") {
                    TextField("Athlete name", text: $name)

                    Picker("Gender", selection: $gender) {
                        Text("Unspecified").tag(Optional<AthleteGender>.none)
                        ForEach(AthleteGender.allCases) { option in
                            Text(option.title).tag(Optional(option))
                        }
                    }

                    DatePicker(
                        "Date of Birth",
                        selection: Binding(
                            get: { dateOfBirth ?? Date() },
                            set: { dateOfBirth = $0 }
                        ),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)

                    if dateOfBirth != nil {
                        Button("Clear Date of Birth", role: .destructive) {
                            dateOfBirth = nil
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmationTitle) {
                        onSave()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}


