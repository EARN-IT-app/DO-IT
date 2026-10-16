// The big STOP IT sign people see when they come to DO IT after their time is up.
import SwiftUI

struct Octagon: Shape {
    func path(in rect: CGRect) -> Path {
        let r = min(rect.width, rect.height) / 2
        let c = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        for i in 0..<8 {
            // Start at 22.5° so the top edge is flat, like a real stop sign.
            let angle = CGFloat(Double(i) * 45 + 22.5) * .pi / 180
            let point = CGPoint(x: c.x + r * cos(angle), y: c.y + r * sin(angle))
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

struct StopView: View {
    var done: () -> Void
    @State private var shown = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 32) {
                Spacer()
                ZStack {
                    Octagon().fill(Color(red: 0.9, green: 0.15, blue: 0.16))
                    Octagon().stroke(Color.white, lineWidth: 10).padding(14)
                    Text("STOP\nIT")
                        .font(.system(size: 96, weight: .black))
                        .multilineTextAlignment(.center)
                        .lineSpacing(-10)
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.5)
                        .padding(40)
                }
                .frame(maxWidth: 320)
                .aspectRatio(1, contentMode: .fit)
                .padding(.horizontal, 24)
                .scaleEffect(shown ? 1 : 0.4)
                .rotationEffect(.degrees(shown ? 0 : -20))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Stop it")
                VStack(spacing: 8) {
                    Text("Your \(Limit.minutes) minutes are used up.").font(.title2.bold())
                    Text("Your apps are locked until midnight. Put the phone down and go do something.")
                        .multilineTextAlignment(.center).foregroundColor(.secondary)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                Spacer()
                Button(action: done) {
                    Text("OK").bold().frame(maxWidth: .infinity, minHeight: 54)
                }
                .buttonStyle(.borderedProminent)
                .tint(doitGreen)
                .foregroundColor(.black)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.5)) { shown = true }
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}
