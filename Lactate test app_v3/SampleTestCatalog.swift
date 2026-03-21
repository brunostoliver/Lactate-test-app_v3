import Foundation

struct SampleStepTemplate {
    let lactate: Double?
    let avgHeartRate: Int?
    let runningPace: String?
    let power: Int?
}

struct SampleTestTemplate: Identifiable {
    let id = UUID()
    let dateString: String
    let sport: Sport
    let steps: [SampleStepTemplate]

    var title: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .none

        let formattedDate = formatter.date(from: dateString).map { displayFormatter.string(from: $0) } ?? dateString
        return "\(sport.rawValue.capitalized) - \(formattedDate)"
    }
}

enum SampleTestCatalog {
    static let all: [SampleTestTemplate] = [
        SampleTestTemplate(
            dateString: "2022-07-06",
            sport: .running,
            steps: [
                SampleStepTemplate(lactate: 1.1, avgHeartRate: 116, runningPace: "6:14", power: 199),
                SampleStepTemplate(lactate: 1.4, avgHeartRate: 121, runningPace: "5:50", power: 216),
                SampleStepTemplate(lactate: 1.5, avgHeartRate: 131, runningPace: "5:25", power: 227),
                SampleStepTemplate(lactate: 2.3, avgHeartRate: 140, runningPace: "4:57", power: 245),
                SampleStepTemplate(lactate: 5.1, avgHeartRate: 153, runningPace: "4:28", power: 270)
            ]
        ),
        SampleTestTemplate(
            dateString: "2022-08-31",
            sport: .running,
            steps: [
                SampleStepTemplate(lactate: 2.0, avgHeartRate: 113, runningPace: "6:14", power: nil),
                SampleStepTemplate(lactate: 1.5, avgHeartRate: 120, runningPace: "5:50", power: nil),
                SampleStepTemplate(lactate: 1.6, avgHeartRate: 126, runningPace: "5:25", power: nil),
                SampleStepTemplate(lactate: 1.7, avgHeartRate: 134, runningPace: "5:00", power: nil),
                SampleStepTemplate(lactate: 2.6, avgHeartRate: 136, runningPace: "4:46", power: nil),
                SampleStepTemplate(lactate: 5.2, avgHeartRate: 145, runningPace: "4:35", power: nil)
            ]
        ),
        SampleTestTemplate(
            dateString: "2022-11-06",
            sport: .running,
            steps: [
                SampleStepTemplate(lactate: 0.9, avgHeartRate: 126, runningPace: "6:09", power: 200),
                SampleStepTemplate(lactate: 1.7, avgHeartRate: 133, runningPace: "5:43", power: 213),
                SampleStepTemplate(lactate: 2.0, avgHeartRate: 138, runningPace: "5:19", power: 227),
                SampleStepTemplate(lactate: 3.1, avgHeartRate: 144, runningPace: "4:52", power: 244),
                SampleStepTemplate(lactate: 4.8, avgHeartRate: 148, runningPace: "4:34", power: 260)
            ]
        ),
        SampleTestTemplate(
            dateString: "2023-01-08",
            sport: .running,
            steps: [
                SampleStepTemplate(lactate: 1.7, avgHeartRate: 117, runningPace: "5:51", power: 210),
                SampleStepTemplate(lactate: 1.2, avgHeartRate: 125, runningPace: "5:34", power: 220),
                SampleStepTemplate(lactate: 1.7, avgHeartRate: 136, runningPace: "5:17", power: 232),
                SampleStepTemplate(lactate: 2.5, avgHeartRate: 143, runningPace: "5:01", power: 247),
                SampleStepTemplate(lactate: 4.1, avgHeartRate: 149, runningPace: "4:38", power: 262)
            ]
        ),
        SampleTestTemplate(
            dateString: "2023-01-25",
            sport: .running,
            steps: [
                SampleStepTemplate(lactate: 1.8, avgHeartRate: 117, runningPace: "6:00", power: 211),
                SampleStepTemplate(lactate: 1.3, avgHeartRate: 125, runningPace: "5:42", power: 221),
                SampleStepTemplate(lactate: 1.5, avgHeartRate: 130, runningPace: "5:20", power: 232),
                SampleStepTemplate(lactate: 1.6, avgHeartRate: 135, runningPace: "5:10", power: 241),
                SampleStepTemplate(lactate: 2.8, avgHeartRate: 142, runningPace: "4:47", power: 257),
                SampleStepTemplate(lactate: 6.2, avgHeartRate: 149, runningPace: "4:26", power: 276)
            ]
        ),
        SampleTestTemplate(
            dateString: "2024-06-09",
            sport: .running,
            steps: [
                SampleStepTemplate(lactate: 1.3, avgHeartRate: 121, runningPace: "6:03", power: 296),
                SampleStepTemplate(lactate: 1.6, avgHeartRate: 127, runningPace: "5:43", power: 310),
                SampleStepTemplate(lactate: 2.0, avgHeartRate: 133, runningPace: "5:21", power: 330),
                SampleStepTemplate(lactate: 2.5, avgHeartRate: 137, runningPace: "5:09", power: 341),
                SampleStepTemplate(lactate: 3.9, avgHeartRate: 142, runningPace: "4:55", power: 347),
                SampleStepTemplate(lactate: 5.4, avgHeartRate: 146, runningPace: "4:46", power: 357)
            ]
        ),
        SampleTestTemplate(
            dateString: "2023-02-25",
            sport: .cycling,
            steps: [
                SampleStepTemplate(lactate: 1.7, avgHeartRate: 119, runningPace: nil, power: 122),
                SampleStepTemplate(lactate: 2.6, avgHeartRate: 127, runningPace: nil, power: 143),
                SampleStepTemplate(lactate: 3.8, avgHeartRate: 136, runningPace: nil, power: 164),
                SampleStepTemplate(lactate: 5.6, avgHeartRate: 141, runningPace: nil, power: 183)
            ]
        ),
        SampleTestTemplate(
            dateString: "2023-04-04",
            sport: .cycling,
            steps: [
                SampleStepTemplate(lactate: 1.7, avgHeartRate: 112, runningPace: nil, power: 122),
                SampleStepTemplate(lactate: 1.8, avgHeartRate: 119, runningPace: nil, power: 143),
                SampleStepTemplate(lactate: 3.2, avgHeartRate: 129, runningPace: nil, power: 163),
                SampleStepTemplate(lactate: 3.7, avgHeartRate: 132, runningPace: nil, power: 183),
                SampleStepTemplate(lactate: 7.2, avgHeartRate: 141, runningPace: nil, power: 209)
            ]
        ),
        SampleTestTemplate(
            dateString: "2023-04-29",
            sport: .cycling,
            steps: [
                SampleStepTemplate(lactate: 1.3, avgHeartRate: 124, runningPace: nil, power: 124),
                SampleStepTemplate(lactate: 1.9, avgHeartRate: 127, runningPace: nil, power: 142),
                SampleStepTemplate(lactate: 2.4, avgHeartRate: 133, runningPace: nil, power: 162),
                SampleStepTemplate(lactate: 3.4, avgHeartRate: 138, runningPace: nil, power: 183),
                SampleStepTemplate(lactate: 7.1, avgHeartRate: 147, runningPace: nil, power: 204)
            ]
        ),
        SampleTestTemplate(
            dateString: "2023-11-25",
            sport: .cycling,
            steps: [
                SampleStepTemplate(lactate: 1.7, avgHeartRate: 117, runningPace: nil, power: 119),
                SampleStepTemplate(lactate: 1.8, avgHeartRate: 123, runningPace: nil, power: 143),
                SampleStepTemplate(lactate: 2.1, avgHeartRate: 129, runningPace: nil, power: 164),
                SampleStepTemplate(lactate: 4.6, avgHeartRate: 137, runningPace: nil, power: 184)
            ]
        )
    ]
}

