// Morning stretches: eight easy stretches, 30 seconds each, with a timer.
import SwiftUI

let stretches: [(icon: String, name: String, how: String)] = [
    ("figure.arms.open", "Reach for the sky", "Stand tall and stretch both arms straight up. Reach higher and higher."),
    ("arrow.triangle.2.circlepath", "Neck rolls", "Slowly roll your head in a circle. Switch directions halfway."),
    ("figure.strengthtraining.functional", "Shoulder rolls", "Roll your shoulders back in big circles, then forward."),
    ("arrow.left.and.right", "Side bends", "Arms up, lean to the left, then to the right. Go slow."),
    ("figure.flexibility", "Touch your toes", "Bend forward and let your arms hang down. Keep your knees soft."),
    ("figure.walk", "Quad stretch", "Hold one foot behind you, then switch legs halfway. Hold a wall if you need."),
    ("circle.dashed", "Hip circles", "Hands on hips, make big circles. Switch directions halfway."),
    ("figure.cooldown", "Cat and cow", "On hands and knees, round your back up, then let it dip down. Repeat."),
]

struct StretchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var step: Int?
    @State private var endsAt = Date()
    @State private var now = Date()
    private let seconds = 30
    private let tick = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Text("MORNING STRETCHES").font(.caption.bold()).foregroundColor(doitGreen)
                Spacer()
                Button("Close") { dismiss() }.foregroundColor(.white)
            }
            if let step, step < stretches.count {
                let s = stretches[step]
                Spacer()
                Image(systemName: s.icon).font(.system(size: 80)).foregroundColor(doitGreen)
                Text(s.name).font(.system(size: 34, weight: .black)).multilineTextAlignment(.center)
                Text(s.how).multilineTextAlignment(.center).foregroundColor(.secondary)
                Text("0:" + String(format: "%02d", max(0, Int(endsAt.timeIntervalSince(now).rounded(.up)))))
                    .font(.system(size: 64, weight: .black).monospacedDigit()).foregroundColor(doitGreen)
                Text("Stretch \(step + 1) of \(stretches.count)").foregroundColor(.secondary)
                Spacer()
                Button { next() } label: { Text("Next stretch").bold().frame(maxWidth: .infinity, minHeight: 54) }
                    .buttonStyle(.bordered)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if step != nil { Text("Done! Nice way to start the day.").font(.title3.bold()).foregroundColor(doitGreen) }
                        ForEach(stretches.indices, id: \.self) { i in
                            HStack(spacing: 14) {
                                Image(systemName: stretches[i].icon).font(.title2).foregroundColor(doitGreen).frame(width: 36)
                                VStack(alignment: .leading) {
                                    Text(stretches[i].name).bold()
                                    Text("30 seconds").font(.subheadline).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Button { start() } label: {
                    Text(step == nil ? "Start stretching (4 minutes)" : "Stretch again").bold().frame(maxWidth: .infinity, minHeight: 60)
                }
                .buttonStyle(.borderedProminent).foregroundColor(.black)
            }
        }
        .padding(24)
        .tint(doitGreen)
        .preferredColorScheme(.dark)
        .onReceive(tick) { t in
            now = t
            if let step, step < stretches.count, t >= endsAt { next() }
        }
    }

    private func start() { step = 0; endsAt = Date().addingTimeInterval(Double(seconds)) }
    private func next() {
        guard let s = step else { return }
        step = s + 1
        endsAt = Date().addingTimeInterval(Double(seconds))
    }
}

import DeviceActivity

extension DeviceActivityReport.Context {
    /// The app checker report (drawn by the DOITReport extension).
    static let opens = Self("opens")
}
