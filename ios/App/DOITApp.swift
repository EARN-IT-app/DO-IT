// DO IT for iPhone. Setup asks for Screen Time access, the apps to limit,
// and how much time they get each day. Screen Time then counts the time, and
// once the day's limit is used up the apps stay blocked until midnight.
import SwiftUI
import FamilyControls
import UserNotifications

@main
struct DOITApp: App {
    var body: some Scene {
        WindowGroup { RootView().tint(.green).preferredColorScheme(.dark) }
    }
}

struct RootView: View {
    @Environment(\.scenePhase) private var phase
    @AppStorage("setUpDone") private var setUpDone = false
    @State private var changing = false

    var body: some View {
        Group {
            if !setUpDone {
                SetupView { setUpDone = true }
            } else {
                TodayView(change: { changing = true })
            }
        }
        .sheet(isPresented: $changing) { ChangeView() }
        .onChange(of: phase) { now in
            if now == .active && setUpDone { Limit.checkDay() }
        }
    }
}

// MARK: - Setup

struct SetupView: View {
    var finished: () -> Void
    @State private var allowed = AuthorizationCenter.shared.authorizationStatus == .approved
    @State private var picking = false
    @State private var selection = Blocker.selection
    @State private var minutes = Limit.minutes
    @State private var problem: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("DO IT").font(.system(size: 56, weight: .black))
                Text("Pick the apps that waste your time and how long you can use them each day. Once the time is used up, they stay locked until tomorrow.")
                    .foregroundColor(.secondary)

                Step(number: 1, title: "Let DO IT use Screen Time",
                     detail: "Your iPhone will ask. Tap Continue, then use Face ID or your passcode. Then tap Allow for notifications, so DO IT can open when your time is up.",
                     done: allowed, button: "Allow Screen Time") {
                    Task {
                        do {
                            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                            allowed = AuthorizationCenter.shared.authorizationStatus == .approved
                            // Notifications are how DO IT gets opened when time's up.
                            _ = try? await UNUserNotificationCenter.current()
                                .requestAuthorization(options: [.alert, .sound])
                        } catch {
                            problem = "Screen Time access wasn't turned on. Tap the button to try again."
                        }
                    }
                }

                Step(number: 2, title: "Pick the apps to limit",
                     detail: "Choose apps like TikTok or Instagram, or a whole group like Social.",
                     done: !Blocker.isEmpty(selection),
                     button: Blocker.isEmpty(selection) ? "Pick apps" : "Change apps") {
                    picking = true
                }
                .disabled(!allowed)

                VStack(alignment: .leading, spacing: 8) {
                    Text("3. Time allowed each day").font(.title3.bold())
                    Text("That's the total for all the apps you picked.").foregroundColor(.secondary)
                    LimitPicker(minutes: $minutes)
                }

                if let problem { Text(problem).foregroundColor(.red) }

                Button {
                    Blocker.selection = selection
                    Limit.minutes = minutes
                    Limit.pendingMinutes = nil
                    Limit.pendingSelection = nil
                    Limit.newDay()
                    finished()
                } label: {
                    Text("Start").bold().frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!allowed || Blocker.isEmpty(selection))
            }
            .padding(24)
        }
        .familyActivityPicker(isPresented: $picking, selection: $selection)
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

struct LimitPicker: View {
    @Binding var minutes: Int

    var body: some View {
        Picker("Time each day", selection: $minutes) {
            ForEach(Limit.choices, id: \.self) { m in
                Text(label(m)).tag(m)
            }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: .infinity, minHeight: 50)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.3)))
    }

    private func label(_ m: Int) -> String {
        m < 60 ? "\(m) minutes" : (m % 60 == 0 ? "\(m / 60) hour\(m == 60 ? "" : "s")" : "\(m / 60) hour \(m % 60) minutes")
    }
}

// MARK: - Today

struct TodayView: View {
    var change: () -> Void
    @State private var now = Date()
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        let locked = Limit.lockedToday
        VStack(spacing: 20) {
            Spacer()
            Text("DO IT").font(.system(size: 56, weight: .black))
            Text(locked ? "DONE FOR TODAY" : "TIME ALLOWED TODAY")
                .font(.caption.bold()).foregroundColor(locked ? .red : .green)
            if locked {
                let midnight = Calendar.current.startOfDay(for: now).addingTimeInterval(86400)
                let left = max(0, Int(midnight.timeIntervalSince(now)))
                Text(String(format: "%d:%02d:%02d", left / 3600, left % 3600 / 60, left % 60))
                    .font(.system(size: 64, weight: .black).monospacedDigit())
                    .foregroundColor(.red)
                Text("You used all your time. Your apps unlock at midnight. Go do the thing you've been putting off.")
                    .multilineTextAlignment(.center).foregroundColor(.secondary)
            } else {
                Text("\(Limit.minutes) min")
                    .font(.system(size: 64, weight: .black))
                    .foregroundColor(.green)
                Text("Your apps are open. Once you've used them for \(Limit.minutes) minutes today, they lock until midnight.")
                    .multilineTextAlignment(.center).foregroundColor(.secondary)
            }
            if Limit.hasPending {
                Text("Your changes start tomorrow.").font(.footnote).foregroundColor(.secondary)
            }
            Spacer()
            Button(action: change) {
                Text("Change apps or time").bold().frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.bordered)
        }
        .padding(32)
        .onReceive(tick) { now = $0 }
    }
}

// MARK: - Change (takes effect tomorrow)

struct ChangeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var picking = false
    @State private var selection = Limit.pendingSelection ?? Blocker.selection
    @State private var minutes = Limit.pendingMinutes ?? Limit.minutes

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Change DO IT").font(.title.bold())
            Text("Changes start tomorrow, so they can't be used to get more time today.")
                .foregroundColor(.secondary)
            Button { picking = true } label: {
                Text("Change apps").bold().frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.bordered)
            Text("Time allowed each day").font(.headline)
            LimitPicker(minutes: $minutes)
            Spacer()
            Button {
                Limit.pendingSelection = selection
                Limit.pendingMinutes = minutes
                dismiss()
            } label: {
                Text("Save for tomorrow").bold().frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.borderedProminent)
            .disabled(Blocker.isEmpty(selection))
            Button("Cancel") { dismiss() }.frame(maxWidth: .infinity)
        }
        .padding(24)
        .familyActivityPicker(isPresented: $picking, selection: $selection)
    }
}
