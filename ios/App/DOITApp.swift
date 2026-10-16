// DO IT for iPhone, with ideas taken from Opal: a fixed 30-minute daily limit on
// the picked apps, focus mode that can't be stopped, a bedtime lock, a streak,
// and a block screen with a quote. Screen Time does the counting and blocking.
import SwiftUI
import FamilyControls
import DeviceActivity
import UserNotifications

@main
struct DOITApp: App {
    init() {
        // "-demo" fills in example numbers, for the screenshots GitHub takes.
        if CommandLine.arguments.contains("-demo") {
            UserDefaults.standard.set(true, forKey: "setUpDone")
            shared.set(dayKey(), forKey: "countingDay")
            shared.set(dayKey(), forKey: "usedDay")
            shared.set(10, forKey: "used")
            shared.set(5, forKey: "streak")
            MorningAlarm.on = true
            MorningAlarm.hour = 7
            MorningAlarm.minute = 0
        }
        // "-demoRingSoon" sets a real alarm for 15 seconds from now, for the video GitHub records.
        if CommandLine.arguments.contains("-demoRingSoon") {
            Task {
                #if canImport(AlarmKit)
                if #available(iOS 26.0, *) { await RealAlarms.ringSoon() }
                #endif
            }
        }
    }

    var body: some Scene {
        WindowGroup { RootView().tint(.green).preferredColorScheme(.dark) }
    }
}

struct RootView: View {
    @Environment(\.scenePhase) private var phase
    @AppStorage("setUpDone") private var setUpDone = false
    @State private var changing = false
    @State private var ringing = MorningAlarm.ringing
    @State private var homework = Homework.on

    var body: some View {
        Group {
            if ringing {
                AlarmView { ringing = false }
            } else if !setUpDone {
                SetupView { setUpDone = true }
            } else if homework {
                HomeworkView { homework = false }
            } else {
                TodayView(change: { changing = true }, startHomework: { Homework.start(); homework = true })
            }
        }
        .sheet(isPresented: $changing) { ChangeView() }
        // Switch to the alarm screen if it goes off while DO IT is open.
        .onReceive(Timer.publish(every: 10, on: .main, in: .common).autoconnect()) { _ in
            if MorningAlarm.ringing != ringing { ringing = MorningAlarm.ringing }
        }
        .onChange(of: phase) { now in
            guard now == .active else { return }
            ringing = MorningAlarm.ringing
            homework = Homework.on
            if setUpDone { Limit.checkDay() }
            if !CommandLine.arguments.contains("-demo") {
                Task { await MorningAlarm.reschedule() } // top up the next few days
            }
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("DO IT").font(.system(size: 56, weight: .black))
                Text("Pick the apps that waste your time. You get \(Limit.minutes) minutes a day on them. Once that's used up, they stay locked until tomorrow.")
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

                if let problem { Text(problem).foregroundColor(.red) }

                Button {
                    Blocker.selection = selection
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

// MARK: - Home

let doitGreen = Color(red: 0, green: 0.82, blue: 0.42)

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

func clock(_ seconds: Int) -> String {
    seconds >= 3600
        ? String(format: "%d:%02d:%02d", seconds / 3600, seconds % 3600 / 60, seconds % 60)
        : String(format: "%d:%02d", seconds / 60, seconds % 60)
}

struct TodayView: View {
    var change: () -> Void
    var startHomework: () -> Void
    @State private var askHomework = false
    @State private var goal = Goal.text(Goal.tomorrow)
    @State private var stretching = false
    @State private var settings = false
    @AppStorage("name", store: shared) private var name = ""
    @State private var now = Date()
    @State private var askFocus: Int?
    @State private var problem: String?
    @State private var bedtime = Bedtime.on
    @State private var alarmOn = MorningAlarm.on
    @State private var alarmTime = MorningAlarm.time
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        let _ = now // redraw every second
        ScrollViewReader { scroll in
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("DO IT").font(.system(size: 30, weight: .black))
                    Spacer()
                    Label("\(Limit.streak) day\(Limit.streak == 1 ? "" : "s")", systemImage: "flame.fill")
                        .font(.headline).foregroundColor(doitGreen)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Color.white.opacity(0.08)).clipShape(Capsule())
                        .accessibilityLabel("\(Limit.streak) day streak")
                    Button { settings = true } label: {
                        Image(systemName: "gearshape.fill").font(.title3).foregroundColor(.white)
                            .frame(width: 44, height: 44).background(Color.white.opacity(0.08)).clipShape(Circle())
                    }
                    .accessibilityLabel("Settings")
                }
                if !name.isEmpty {
                    Text("Hi, \(name). Let's get things done.").font(.headline).foregroundColor(.secondary)
                }

                todayCard
                // Shortcuts under the ring: each jumps to its settings below.
                HStack(spacing: 8) {
                    chip("scope", "Focus", Focus.active ? "On now" : "Lock now") { withAnimation { scroll.scrollTo("focus", anchor: .center) } }
                    chip("moon.fill", "Bedtime", bedtime ? "On · 10 PM" : "Off") { withAnimation { scroll.scrollTo("bedtime", anchor: .center) } }
                    chip("alarm.fill", "Alarm", alarmOn ? alarmTime.formatted(date: .omitted, time: .shortened) : "Off") { withAnimation { scroll.scrollTo("alarm", anchor: .center) } }
                    chip("figure.flexibility", "Stretch", "Morning") { stretching = true }
                }
                focusCard.id("focus")
                homeworkCard
                goalCard
                opensCard
                weekCard
                bedtimeCard.id("bedtime")
                alarmCard.id("alarm")

                Button(action: change) {
                    Text("Change apps").bold().frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.bordered)
                if Limit.hasPending {
                    Text("Your app changes start tomorrow.").font(.footnote).foregroundColor(.secondary)
                }
            }
            .padding(20)
        }
        }
        .background(RadialGradient(colors: [Color(red: 0.05, green: 0.23, blue: 0.13), .black],
                                   center: UnitPoint(x: 0.5, y: 0.2), startRadius: 0, endRadius: 420).ignoresSafeArea())
        .onReceive(tick) { now = $0 }
        .alert("Focus for \(askFocus ?? 0) minutes?", isPresented: Binding(get: { askFocus != nil }, set: { if !$0 { askFocus = nil } })) {
            Button("Lock my apps") {
                if let m = askFocus {
                    do { try Focus.start(minutes: m) } catch { problem = "Focus mode couldn't start. Try again in a moment." }
                }
            }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("Your apps lock right now. There's no way to cancel until the time is up.")
        }
        .sheet(isPresented: $stretching) { StretchView() }
        .sheet(isPresented: $settings) { SettingsView(change: { settings = false; change() }) }
        .alert("Lock your apps until your homework is done?", isPresented: $askHomework) {
            Button("Lock my apps") { startHomework() }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("You can only unlock them with a picture of your finished homework.")
        }
        .alert(problem ?? "", isPresented: Binding(get: { problem != nil }, set: { if !$0 { problem = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }

    private var homeworkCard: some View {
        Card {
            Text("HOMEWORK LOCK").font(.caption.bold()).foregroundColor(doitGreen)
            Text("Locks your apps until you take a picture of your finished homework.").foregroundColor(.secondary)
            Button { askHomework = true } label: {
                Text("Start homework lock").bold().frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent).foregroundColor(.black)
        }
    }

    private var goalCard: some View {
        Card {
            Text("TOMORROW'S GOAL").font(.caption.bold()).foregroundColor(doitGreen)
            if !Goal.today.isEmpty { Text("Today's goal: \(Goal.today)") }
            Text("What do you want to get done tomorrow?").font(.headline)
            TextField("Finish my essay", text: $goal)
                .textFieldStyle(.roundedBorder)
                .onChange(of: goal) { Goal.save($0.trimmingCharacters(in: .whitespaces), Goal.tomorrow) }
            Text("It shows up on your alarm in the morning.").font(.footnote).foregroundColor(.secondary)
        }
    }

    /// App checker: how many times each app was opened today. iPhone only lets
    /// DO IT show this inside a Screen Time report, so the numbers are drawn by the report.
    private var opensCard: some View {
        Card {
            Text("APP CHECKER").font(.caption.bold()).foregroundColor(doitGreen)
            Text("How many times you opened each app today.").foregroundColor(.secondary)
            DeviceActivityReport(.opens, filter: DeviceActivityFilter(
                segment: .daily(during: DateInterval(start: Calendar.current.startOfDay(for: Date()), end: Date()))))
                .frame(height: 320)
        }
    }

    private var weekCard: some View {
        let days = (0..<7).reversed().map { Date().addingTimeInterval(-86400 * Double($0)) }
        let mins = days.map { Limit.used(on: $0) }
        let past = Array(zip(days, mins).dropLast())
        let best = past.min { $0.1 < $1.1 }
        let weekday = DateFormatter(); weekday.dateFormat = "EEEEE"
        let longDay = DateFormatter(); longDay.dateFormat = "EEEE"
        return Card {
            Text("THIS WEEK").font(.caption.bold()).foregroundColor(doitGreen)
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<7, id: \.self) { i in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(mins[i] >= Limit.minutes ? Color.red : doitGreen)
                            .frame(height: max(4, CGFloat(min(mins[i], Limit.minutes)) / CGFloat(Limit.minutes) * 110))
                        Text(weekday.string(from: days[i])).font(.caption.bold())
                            .foregroundColor(i == 6 ? .white : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 135, alignment: .bottom)
            if let best {
                Text("\(mins.reduce(0, +)) minutes used this week. Best day: \(longDay.string(from: best.0)) (\(best.1) min).")
                    .font(.footnote).foregroundColor(.secondary)
            }
        }
    }

    private func chip(_ icon: String, _ title: String, _ detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.title2).foregroundColor(doitGreen)
                Text(title).bold().foregroundColor(.white)
                Text(detail).font(.footnote).foregroundColor(.secondary).lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(Color.white.opacity(0.07))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.1)))
            .clipShape(RoundedRectangle(cornerRadius: 22))
        }
    }

    @ViewBuilder private var todayCard: some View {
        if !Limit.lockedToday {
            // One big ring for the time left today.
            let used = Limit.usedToday
            VStack(spacing: 10) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.1), lineWidth: 16)
                    Circle().trim(from: 0, to: CGFloat(Limit.minutes - used) / CGFloat(Limit.minutes))
                        .stroke(doitGreen, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 4) {
                        Text("\(Limit.minutes - used)").font(.system(size: 84, weight: .black))
                        Text("minutes left today").font(.headline).foregroundColor(.secondary)
                    }
                }
                .frame(width: 260, height: 260)
                Text("You've used \(used) of your \(Limit.minutes) minutes.").foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        } else {
        Card {
            if Limit.lockedToday {
                let midnight = Calendar.current.startOfDay(for: now).addingTimeInterval(86400)
                Text("DONE FOR TODAY").font(.caption.bold()).foregroundColor(.red)
                Text(clock(max(0, Int(midnight.timeIntervalSince(now)))))
                    .font(.system(size: 48, weight: .black).monospacedDigit()).foregroundColor(.red)
                Text("You used all \(Limit.minutes) minutes. Your apps unlock at midnight.")
                    .foregroundColor(.secondary)
            } else {
                let used = Limit.usedToday
                Text("TODAY").font(.caption.bold()).foregroundColor(doitGreen)
                HStack(spacing: 20) {
                    ZStack {
                        Circle().stroke(Color.white.opacity(0.12), lineWidth: 12)
                        Circle().trim(from: 0, to: CGFloat(used) / CGFloat(Limit.minutes))
                            .stroke(doitGreen, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("\(Limit.minutes - used)").font(.system(size: 30, weight: .black))
                    }
                    .frame(width: 96, height: 96)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("about \(Limit.minutes - used) min left").font(.title3.bold())
                        Text("You get \(Limit.minutes) minutes a day. When they're gone, your apps lock until midnight.")
                            .font(.subheadline).foregroundColor(.secondary)
                    }
                }
            }
        }
        }
    }

    private var focusCard: some View {
        Card {
            Text("FOCUS MODE").font(.caption.bold()).foregroundColor(doitGreen)
            if Focus.active {
                Text(clock(max(0, Int(Focus.endsAt.timeIntervalSince(now)))))
                    .font(.system(size: 48, weight: .black).monospacedDigit()).foregroundColor(doitGreen)
                Text("Your apps are locked. Go get it done.").foregroundColor(.secondary)
            } else {
                Text("Lock your apps right now. Once it starts, it can't be stopped.").foregroundColor(.secondary)
                HStack {
                    ForEach(Focus.choices, id: \.self) { m in
                        Button { askFocus = m } label: {
                            Text(m < 60 ? "\(m)m" : "\(m / 60)h").bold().frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.borderedProminent)
                        .foregroundColor(.black)
                    }
                }
            }
        }
    }

    private var alarmCard: some View {
        Card {
            Toggle(isOn: Binding(get: { alarmOn }, set: { want in
                if !want && MorningAlarm.ringing {
                    problem = "The alarm can't be turned off while it's going off. Take a picture of the sink."
                    return
                }
                alarmOn = want
                MorningAlarm.on = want
                Task { await MorningAlarm.reschedule() }
            })) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MORNING ALARM").font(.caption.bold()).foregroundColor(doitGreen)
                    Text("Goes off every minute, with no snooze, until you get up and take a picture of the sink.")
                        .foregroundColor(.secondary)
                }
            }
            .tint(doitGreen)
            if alarmOn {
                DatePicker("Wake up at", selection: $alarmTime, displayedComponents: .hourAndMinute)
                    .font(.headline)
                    .onChange(of: alarmTime) { t in
                        let c = Calendar.current.dateComponents([.hour, .minute], from: t)
                        MorningAlarm.hour = c.hour ?? 7
                        MorningAlarm.minute = c.minute ?? 0
                        Task { await MorningAlarm.reschedule() }
                    }
            }
            Text("Alarm video: \"Just Do It\" by Shia LaBeouf, from #INTRODUCTIONS by LaBeouf, Rönkkö & Turner (2015). Played from YouTube.")
                .font(.footnote).foregroundColor(.secondary)
        }
    }

    private var bedtimeCard: some View {
        Card {
            Toggle(isOn: Binding(get: { bedtime }, set: { want in
                if want {
                    do { try Bedtime.turnOn(); bedtime = true } catch { problem = "Bedtime lock couldn't turn on. Try again in a moment." }
                } else if Bedtime.isNight {
                    problem = "Bedtime lock can only be turned off during the day."
                } else {
                    Bedtime.turnOff(); bedtime = false
                }
            })) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("BEDTIME LOCK").font(.caption.bold()).foregroundColor(doitGreen)
                    Text("Locks your apps every night from 10 PM to 7 AM.").foregroundColor(.secondary)
                }
            }
            .tint(doitGreen)
        }
    }
}

// MARK: - Change (takes effect tomorrow)

struct ChangeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var picking = false
    @State private var selection = Limit.pendingSelection ?? Blocker.selection

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Change apps").font(.title.bold())
            Text("Changes start tomorrow, so they can't be used to get more time today.")
                .foregroundColor(.secondary)
            Button { picking = true } label: {
                Text("Change apps").bold().frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.bordered)
            Spacer()
            Button {
                Limit.pendingSelection = selection
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
