import SwiftUI

struct StepEditor: View {
    @Binding var step: LactateStep
    let sport: Sport
    let unitPreference: UnitPreference

    @State private var paceMinutesText: String = ""
    @State private var paceSecondsText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Step \(step.stepIndex)")
                    .font(.subheadline).bold()

                // Lactate mmol/L
                HStack(spacing: 4) {
                    Text("Lactate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("mmol/L", value: $step.lactate, format: .number)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                }

                // HR bpm
                HStack(spacing: 4) {
                    Text("HR")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("bpm", value: $step.avgHeartRate, format: .number)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 70)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                if sport == .running {
                    // Running pace (seconds per km)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pace")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(spacing: 6) {
                            HStack(spacing: 4) {
                                TextField("min", text: $paceMinutesText)
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 60)

                                Text(":")
                                    .foregroundStyle(.secondary)

                                TextField("sec", text: $paceSecondsText)
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 60)
                            }
                            Text(step.runningPaceSecondsPerKm.map { PaceFormatter.string(fromSecondsPerKm: $0, unit: unitPreference) } ?? "-")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .onAppear {
                            if let secs = step.runningPaceSecondsPerKm {
                                let m = max(0, secs / 60)
                                let s = max(0, secs % 60)
                                paceMinutesText = m == 0 ? "" : String(m)
                                paceSecondsText = s == 0 ? "" : String(s)
                            } else {
                                paceMinutesText = ""
                                paceSecondsText = ""
                            }
                        }
                        .onChange(of: paceMinutesText) { _, newValue in
                            let filtered = newValue.filter { $0.isNumber }
                            if filtered != newValue { paceMinutesText = filtered }
                            let m = Int(filtered) ?? 0
                            let s = min(max(Int(paceSecondsText) ?? 0, 0), 59)
                            step.runningPaceSecondsPerKm = max(0, m) * 60 + s
                        }
                        .onChange(of: paceSecondsText) { _, newValue in
                            let filtered = newValue.filter { $0.isNumber }
                            if filtered != newValue { paceSecondsText = filtered }
                            let m = max(Int(paceMinutesText) ?? 0, 0)
                            let s = min(max(Int(filtered) ?? 0, 0), 59)
                            step.runningPaceSecondsPerKm = m * 60 + s
                        }
                        .onChange(of: step.runningPaceSecondsPerKm) { _, newValue in
                            if let secs = newValue {
                                let m = max(0, secs / 60)
                                let s = max(0, secs % 60)
                                // Only prefill if fields are empty to avoid overriding user typing
                                if paceMinutesText.isEmpty { paceMinutesText = m == 0 ? "" : String(m) }
                                if paceSecondsText.isEmpty { paceSecondsText = s == 0 ? "" : String(s) }
                            }
                        }
                    }
                } else if sport == .cycling {
                    // Cycling speed (km/h)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Speed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(spacing: 6) {
                            TextField("km/h", value: $step.cyclingSpeedKmh, format: .number)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 90)
                            Text(step.cyclingSpeedKmh.map { SpeedFormatter.string(fromKmh: $0, unit: unitPreference) } ?? "-")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Power watts (optional for both sports)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Power")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("W", value: $step.powerWatts, format: .number)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }

                Spacer(minLength: 0)
            }
        }
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}
#Preview {
    struct StepEditor_Previews: View {
        @State private var step = LactateStep(stepIndex: 1, lactate: 1.8, avgHeartRate: 120, runningPaceSecondsPerKm: 300, cyclingSpeedKmh: 28.5, powerWatts: 180)
        var body: some View {
            StepEditor(step: $step, sport: .cycling, unitPreference: .metric)
                .padding()
        }
    }
    return StepEditor_Previews()
}

