import SwiftUI

struct PaceInput: View {
    @Binding var secondsPerKm: Int?
    let unitPreference: UnitPreference

    @State private var minutes: String = ""
    @State private var seconds: String = ""

    var body: some View {
        HStack(spacing: 4) {
            Text("Pace")

            TextField("min", text: Binding(
                get: { minutes },
                set: { newValue in
                    minutes = newValue
                    updateBinding()
                }
            ))
            .keyboardType(.numberPad)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .frame(width: 50)

            Text(":")

            TextField("sec", text: Binding(
                get: { seconds },
                set: { newValue in
                    seconds = newValue
                    updateBinding()
                }
            ))
            .keyboardType(.numberPad)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .frame(width: 50)

            Text(paceUnitLabel)
        }
        .onAppear(perform: syncFromBinding)
        .onChange(of: unitPreference) {
            syncFromBinding()
        }
    }

    private var paceUnitLabel: String {
        switch unitPreference {
        case .metric:
            return "min/km"
        case .imperial:
            return "min/mile"
        }
    }

    private func syncFromBinding() {
        guard let totalSecondsPerKm = secondsPerKm else {
            minutes = ""
            seconds = ""
            return
        }

        let displayedTotalSeconds: Double
        switch unitPreference {
        case .metric:
            displayedTotalSeconds = Double(totalSecondsPerKm)
        case .imperial:
            displayedTotalSeconds = Double(totalSecondsPerKm) * 1.60934
        }

        let rounded = Int(displayedTotalSeconds.rounded())
        minutes = String(rounded / 60)
        seconds = String(format: "%02d", rounded % 60)
    }

    private func updateBinding() {
        let m = Int(minutes) ?? 0
        let s = Int(seconds) ?? 0
        let clampedS = max(0, min(59, s))
        let displayedTotal = m * 60 + clampedS

        guard displayedTotal > 0 else {
            secondsPerKm = nil
            return
        }

        let storedSecondsPerKm: Double
        switch unitPreference {
        case .metric:
            storedSecondsPerKm = Double(displayedTotal)
        case .imperial:
            storedSecondsPerKm = Double(displayedTotal) / 1.60934
        }

        secondsPerKm = Int(storedSecondsPerKm.rounded())
    }
}
