import SwiftUI

struct StepEditor: View {
    @Binding var step: LactateStep
    let sport: Sport
    let unitPreference: UnitPreference

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Step \(step.stepIndex)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                TextField("Lactate (mmol/L)", text: doubleStringBinding($step.lactate))
                    .keyboardType(.decimalPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                TextField("Avg HR", text: intStringBinding($step.avgHeartRate))
                    .keyboardType(.numberPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                if sport == .running {
                    PaceInput(
                        secondsPerKm: $step.runningPaceSecondsPerKm,
                        unitPreference: unitPreference
                    )
                } else {
                    TextField(
                        speedFieldTitle,
                        text: speedStringBinding($step.cyclingSpeedKmh)
                    )
                    .keyboardType(.decimalPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                TextField("Power (W)", text: intStringBinding($step.powerWatts))
                    .keyboardType(.numberPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var speedFieldTitle: String {
        switch unitPreference {
        case .metric:
            return "Speed (km/h)"
        case .imperial:
            return "Speed (mph)"
        }
    }

    private func intStringBinding(_ value: Binding<Int?>) -> Binding<String> {
        Binding<String>(
            get: {
                if let wrapped = value.wrappedValue {
                    return String(wrapped)
                }
                return ""
            },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                value.wrappedValue = trimmed.isEmpty ? nil : Int(trimmed)
            }
        )
    }

    private func doubleStringBinding(_ value: Binding<Double?>) -> Binding<String> {
        Binding<String>(
            get: {
                if let wrapped = value.wrappedValue {
                    return String(wrapped)
                }
                return ""
            },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    value.wrappedValue = nil
                } else {
                    value.wrappedValue = Double(trimmed.replacingOccurrences(of: ",", with: "."))
                }
            }
        )
    }

    private func speedStringBinding(_ value: Binding<Double?>) -> Binding<String> {
        Binding<String>(
            get: {
                guard let kmh = value.wrappedValue else { return "" }

                switch unitPreference {
                case .metric:
                    return String(format: "%.1f", kmh)
                case .imperial:
                    let mph = kmh / 1.60934
                    return String(format: "%.1f", mph)
                }
            },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)

                guard !trimmed.isEmpty else {
                    value.wrappedValue = nil
                    return
                }

                guard let enteredValue = Double(trimmed.replacingOccurrences(of: ",", with: ".")) else {
                    value.wrappedValue = nil
                    return
                }

                switch unitPreference {
                case .metric:
                    value.wrappedValue = enteredValue
                case .imperial:
                    value.wrappedValue = enteredValue * 1.60934
                }
            }
        )
    }
}

