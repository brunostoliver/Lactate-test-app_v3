import SwiftUI
import Charts

struct LactateChartView: View {
    let graphXAxis: GraphXAxis
    let displaySeries: [GraphSeries]
    let yAxisDomain: ClosedRange<Double>
    let xAxisDomain: ClosedRange<Double>
    let lt1Point: ThresholdPoint?
    let dmaxPoint: ThresholdPoint?
    let lt2Point: ThresholdPoint?

    @Binding var selectedPoint: GraphPoint?

    let nearestPointProvider: (Double) -> GraphPoint?
    let formatXAxisValue: (Double) -> String

    var body: some View {
        Chart {
            RuleMark(y: .value("LT1", 2.0))
                .foregroundStyle(.green)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))

            RuleMark(y: .value("LT2", 4.0))
                .foregroundStyle(.red)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))

            ForEach(displaySeries) { series in
                ForEach(series.points) { point in
                    LineMark(
                        x: .value(graphXAxis.title, point.x),
                        y: .value("Lactate", point.lactate),
                        series: .value("Series", series.id)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(series.color)

                    PointMark(
                        x: .value(graphXAxis.title, point.x),
                        y: .value("Lactate", point.lactate)
                    )
                    .foregroundStyle(series.color)
                    .symbolSize(50)
                }
            }

            if let lt1Point {
                RuleMark(x: .value("LT1 X", lt1Point.x))
                    .foregroundStyle(.green)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }

            if let dmaxPoint {
                RuleMark(x: .value("Dmax X", dmaxPoint.x))
                    .foregroundStyle(.purple)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }

            if let lt2Point {
                RuleMark(x: .value("LT2 X", lt2Point.x))
                    .foregroundStyle(.red)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }

            if let selected = selectedPoint {
                RuleMark(x: .value("Selected X", selected.x))
                    .foregroundStyle(.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

                PointMark(
                    x: .value("Selected Point X", selected.x),
                    y: .value("Selected Point Y", selected.lactate)
                )
                .foregroundStyle(selected.seriesColor)
                .symbolSize(130)
                .annotation(position: .top, alignment: .leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selected.seriesLabel)
                            .font(.caption)
                            .bold()
                        Text("Step \(selected.stepIndex)")
                            .font(.caption2)
                        Text("\(graphXAxis.title): \(formatXAxisValue(selected.x))")
                            .font(.caption2)
                        Text(String(format: "Lactate: %.2f", selected.lactate))
                            .font(.caption2)
                    }
                    .padding(6)
                    .background(Color(.systemBackground).opacity(0.95))
                    .cornerRadius(8)
                }
            }
        }
        .chartXAxisLabel(graphXAxis.title)
        .chartYAxisLabel("Lactate (mmol/L)")
        .chartYScale(domain: yAxisDomain)
        .chartXScale(domain: xAxisDomain)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard let plotFrameAnchor = proxy.plotFrame else {
                                    return
                                }

                                let plotFrame = geometry[plotFrameAnchor]
                                let relativeX = value.location.x - plotFrame.origin.x

                                guard relativeX >= 0, relativeX <= plotFrame.size.width else {
                                    return
                                }

                                if let xValue: Double = proxy.value(atX: relativeX) {
                                    selectedPoint = nearestPointProvider(xValue)
                                }
                            }
                    )
            }
        }
    }
}

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

struct ExportLactateChartView: View {
    let points: [GraphPoint]
    let yAxisDomain: ClosedRange<Double>
    let xAxisDomain: ClosedRange<Double>
    let lt1Point: ThresholdPoint?
    let dmaxPoint: ThresholdPoint?
    let lt2Point: ThresholdPoint?
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            Chart {
                RuleMark(y: .value("LT1", 2.0))
                    .foregroundStyle(.green)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))

                RuleMark(y: .value("LT2", 4.0))
                    .foregroundStyle(.red)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))

                ForEach(points) { point in
                    LineMark(
                        x: .value("Power", point.x),
                        y: .value("Lactate", point.lactate)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(.blue)

                    PointMark(
                        x: .value("Power", point.x),
                        y: .value("Lactate", point.lactate)
                    )
                    .foregroundStyle(.blue)
                }

                if let lt1Point {
                    RuleMark(x: .value("LT1 X", lt1Point.x))
                        .foregroundStyle(.green)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }

                if let dmaxPoint {
                    RuleMark(x: .value("Dmax X", dmaxPoint.x))
                        .foregroundStyle(.purple)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }

                if let lt2Point {
                    RuleMark(x: .value("LT2 X", lt2Point.x))
                        .foregroundStyle(.red)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
            }
            .chartXAxisLabel("Power")
            .chartYAxisLabel("Lactate (mmol/L)")
            .chartYScale(domain: yAxisDomain)
            .chartXScale(domain: xAxisDomain)
        }
        .padding()
        .background(Color.white)
    }
}
