import SwiftUI

struct SampleTestPickerView: View {
    let onSelect: (SampleTestTemplate) -> Void
    let onLoadAll: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var runningSamples: [SampleTestTemplate] {
        SampleTestCatalog.all.filter { $0.sport == .running }
    }

    private var cyclingSamples: [SampleTestTemplate] {
        SampleTestCatalog.all.filter { $0.sport == .cycling }
    }

    var body: some View {
        NavigationStack {
            HStack(alignment: .top) {
                Spacer(minLength: 0)

                List {
                    Section("Running") {
                        ForEach(runningSamples) { sample in
                            Button(sample.title) {
                                onSelect(sample)
                                dismiss()
                            }
                        }
                    }

                    Section("Cycling") {
                        ForEach(cyclingSamples) { sample in
                            Button(sample.title) {
                                onSelect(sample)
                                dismiss()
                            }
                        }
                    }
                }
                .frame(maxWidth: 760)

                Spacer(minLength: 0)
            }
            .navigationTitle("Sample Tests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Load All") {
                        onLoadAll()
                        dismiss()
                    }
                }
            }
        }
    }
}


