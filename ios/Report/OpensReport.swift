// The app checker: a Screen Time report that shows how many times each app was
// opened today. iPhone keeps this information private, so only this report can see it.
import DeviceActivity
import SwiftUI

@main
struct DOITReport: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        OpensReport { OpensView(rows: $0) }
    }
}

extension DeviceActivityReport.Context {
    static let opens = Self("opens")
}

struct AppOpens: Identifiable {
    let id = UUID()
    let name: String
    let opens: Int
}

struct OpensReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .opens
    let content: ([AppOpens]) -> OpensView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> [AppOpens] {
        var totals: [String: Int] = [:]
        for await day in data {
            for await segment in day.activitySegments {
                for await category in segment.categories {
                    for await app in category.applications {
                        let name = app.application.localizedDisplayName ?? "App"
                        totals[name, default: 0] += app.numberOfPickups
                    }
                }
            }
        }
        return totals.filter { $0.value > 0 }
            .map { AppOpens(name: $0.key, opens: $0.value) }
            .sorted { $0.opens > $1.opens }
    }
}

struct OpensView: View {
    let rows: [AppOpens]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("\(rows.reduce(0) { $0 + $1.opens })")
                    .font(.system(size: 48, weight: .black)).foregroundColor(.white)
                Text("times you picked up your phone to open an app today")
                    .font(.subheadline).foregroundColor(.gray)
                ForEach(rows.prefix(12)) { row in
                    HStack {
                        Text(row.name).foregroundColor(.white).lineLimit(1)
                        Spacer()
                        Text("\(row.opens)").bold().foregroundColor(Color(red: 0, green: 0.82, blue: 0.42))
                    }
                    .padding(.vertical, 4)
                }
                if rows.isEmpty { Text("No apps opened yet today.").foregroundColor(.gray) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.clear)
    }
}
