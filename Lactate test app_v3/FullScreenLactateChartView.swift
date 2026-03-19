import SwiftUI

struct FullScreenLactateChartView: View {
    let title: String
    let graphXAxis: GraphXAxis
    let displaySeries: [GraphSeries]
    let yAxisDomain: ClosedRange<Double>
    let baseXAxisDomain: ClosedRange<Double>
    let lt1Point: ThresholdPoint?
    let dmaxPoint: ThresholdPoint?
    let lt2Point: ThresholdPoint?

    @Binding var selectedPoint: GraphPoint?

    let nearestPointProvider: (Double) -> GraphPoint?
    let formatXAxisValue: (Double) -> String

    @Environment(\.dismiss) private var dismiss

    @State private var currentXAxisDomain: ClosedRange<Double> = 0.0...1.0
    @State private var pinchStartDomain: ClosedRange<Double> = 0.0...1.0

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Button(action: zoomIn) {
                        Label("Zoom In", systemImage: "plus.magnifyingglass")
                    }

                    Button(action: zoomOut) {
                        Label("Zoom Out", systemImage: "minus.magnifyingglass")
                    }

                    Button(action: resetZoom) {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }

                    Spacer()
                }
                .font(.caption)

                LactateChartView(
                    graphXAxis: graphXAxis,
                    displaySeries: displaySeries,
                    yAxisDomain: yAxisDomain,
                    xAxisDomain: currentXAxisDomain,
                    lt1Point: lt1Point,
                    dmaxPoint: dmaxPoint,
                    lt2Point: lt2Point,
                    selectedPoint: $selectedPoint,
                    nearestPointProvider: nearestPointProvider,
                    formatXAxisValue: formatXAxisValue
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            applyMagnification(value)
                        }
                )
            }
            .padding()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                currentXAxisDomain = baseXAxisDomain
                pinchStartDomain = baseXAxisDomain
            }
        }
    }

    private func zoomIn() {
        currentXAxisDomain = scaledDomain(from: currentXAxisDomain, scale: 0.8)
        pinchStartDomain = currentXAxisDomain
    }

    private func zoomOut() {
        currentXAxisDomain = scaledDomain(from: currentXAxisDomain, scale: 1.25)
        pinchStartDomain = currentXAxisDomain
    }

    private func resetZoom() {
        currentXAxisDomain = baseXAxisDomain
        pinchStartDomain = baseXAxisDomain
    }

    private func applyMagnification(_ value: CGFloat) {
        guard value > 0 else { return }
        let scale = 1.0 / Double(value)
        currentXAxisDomain = scaledDomain(from: pinchStartDomain, scale: scale)
    }

    private func scaledDomain(from domain: ClosedRange<Double>, scale: Double) -> ClosedRange<Double> {
        let baseMin = baseXAxisDomain.lowerBound
        let baseMax = baseXAxisDomain.upperBound
        let baseWidth = baseMax - baseMin

        let currentMin = domain.lowerBound
        let currentMax = domain.upperBound
        let currentWidth = currentMax - currentMin

        let center = (currentMin + currentMax) / 2.0
        var newWidth = currentWidth * scale

        let minimumWidth = max(baseWidth * 0.15, 1.0)
        let maximumWidth = baseWidth

        newWidth = max(minimumWidth, min(maximumWidth, newWidth))

        var newMin = center - newWidth / 2.0
        var newMax = center + newWidth / 2.0

        if newMin < baseMin {
            newMin = baseMin
            newMax = newMin + newWidth
        }

        if newMax > baseMax {
            newMax = baseMax
            newMin = newMax - newWidth
        }

        if newMin < baseMin {
            newMin = baseMin
        }

        if newMax > baseMax {
            newMax = baseMax
        }

        return newMin...newMax
    }
}

