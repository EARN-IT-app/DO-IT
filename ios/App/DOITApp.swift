// DO IT for iPhone. Setup asks for Screen Time access and the apps to block.
// After that the app shows the DO IT website (outdoor photo, then the video).
// Finishing it opens doit://break?minutes=N, which lifts the block for the break.
import SwiftUI
import FamilyControls
import UserNotifications

let siteURL = URL(string: "https://wonderbread4912.github.io/DO-IT/?from=ios")!

@main
struct DOITApp: App {
    var body: some Scene {
        WindowGroup { RootView().tint(.green).preferredColorScheme(.dark) }
    }
}

struct RootView: View {
    @Environment(\.scenePhase) private var phase
    @AppStorage("setUpDone") private var setUpDone = false
    @State private var onBreak = Break.active

    var body: some View {
        Group {
            if !setUpDone {
                SetupView { setUpDone = true }
            } else if onBreak {
                BreakView { onBreak = false }
            } else {
                ChallengeView(onBreakStarted: { onBreak = true })
            }
        }
        .onChange(of: phase) { now in
            guard now == .active else { return }
            // Backup in case the break ended while the phone was busy.
            if !Break.active && shared.double(forKey: "breakEnd") > 0 { Break.end() }
            onBreak = Break.active
            if !onBreak { Blocker.shieldOn() }
        }
    }
}

// MARK: - Setup

struct SetupView: View {
    var finished: () -> Void
    @State private var allowed = AuthorizationCenter.shared.authorizationStatus == .approved
    @State private var picking = false
    @State private var selection = Blocker.selection
    @State private var problem: String?

    private var hasApps: Bool {
        !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty || !selection.webDomainTokens.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("DO IT").font(.system(size: 56, weight: .black))
                Text("Pick the apps that waste your time. When you open one, DO IT stops you until you go outside, take a photo of the sky, and watch the video.")
                    .foregroundColor(.secondary)

                Step(number: 1, title: "Let DO IT use Screen Time",
                     detail: "Your iPhone will ask. Tap Continue, then use Face ID or your passcode.",
                     done: allowed, button: "Allow Screen Time") {
                    Task {
                        do {
                            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                            allowed = AuthorizationCenter.shared.authorizationStatus == .approved
                            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
                        } catch {
                            problem = "Screen Time access wasn't turned on. Tap the button to try again."
                        }
                    }
                }

                Step(number: 2, title: "Pick the apps to block",
                     detail: "Choose apps like TikTok or Instagram, or a whole group like Social.",
                     done: hasApps, button: hasApps ? "Change apps" : "Pick apps") {
                    picking = true
                }
                .disabled(!allowed)

                if let problem { Text(problem).foregroundColor(.red) }

                Button(action: finished) {
                    Text("Start blocking").bold().frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!allowed || !hasApps)
            }
            .padding(24)
        }
        .familyActivityPicker(isPresented: $picking, selection: $selection)
        .onChange(of: selection) { picked in
            Blocker.selection = picked
            Blocker.shieldOn()
        }
    }
}

struct Step: View {
    let number: Int
    let title: String
    let detail: String
    let done: Bool
    let button: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(number). \(title)").font(.title3.bold())
            Text(detail).foregroundColor(.secondary)
            if done && number == 1 {
                Label("Done", systemImage: "checkmark.circle.fill").foregroundColor(.green).bold()
            } else {
                Button(action: action) {
                    Text(button).bold().frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.bordered)
                if done { Label("Done", systemImage: "checkmark.circle.fill").foregroundColor(.green).bold() }
            }
        }
    }
}

// MARK: - Challenge (the DO IT website inside the app)

struct ChallengeView: View {
    var onBreakStarted: () -> Void
    @State private var problem: String?
    @AppStorage("setUpDone") private var setUpDone = true

    var body: some View {
        ZStack(alignment: .topTrailing) {
            WebView(url: siteURL) { minutes in
                do {
                    try Break.start(minutes: minutes)
                    onBreakStarted()
                } catch {
                    problem = "Your break couldn't start. Try again in a moment."
                }
            }
            .ignoresSafeArea(edges: .bottom)

            Button { setUpDone = false } label: {
                Image(systemName: "gearshape.fill").font(.title2).padding(12)
            }
            .accessibilityLabel("Change blocked apps")
        }
        .alert(problem ?? "", isPresented: Binding(get: { problem != nil }, set: { if !$0 { problem = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }
}

// MARK: - Break

struct BreakView: View {
    var ended: () -> Void
    @State private var now = Date()
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        let left = max(0, Int(Break.endsAt.timeIntervalSince(now)))
        VStack(spacing: 20) {
            Text("YOUR BREAK").font(.caption.bold()).foregroundColor(.green)
            Text(String(format: "%d:%02d", left / 60, left % 60))
                .font(.system(size: 72, weight: .black).monospacedDigit())
                .foregroundColor(.green)
            Text("Your apps are open. When the timer hits zero they lock again, and you start over from step 1.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding(32)
        .onReceive(tick) { date in
            now = date
            if !Break.active {
                Break.end()
                ended()
            }
        }
    }
}
