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

