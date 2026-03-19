import SwiftUI
import Charts

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

