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
    // Shown each time DO IT opens after the day's time is used up.
    @State private var stop = Limit.lockedToday || CommandLine.arguments.contains("-demoStop")

    var body: some View {
        Group {
            if ringing {
                AlarmView { ringing = false }
            } else if stop && setUpDone {
                StopView { stop = false }
            } else if !setUpDone {
                SetupView { setUpDone = true }
            } else {
                TodayView(change: { changing = true })
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
            if setUpDone { Limit.checkDay() }
            stop = Limit.lockedToday || CommandLine.arguments.contains("-demoStop")
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
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 14) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 72, height: 72)
                        .background(LinearGradient(colors: [doitGreenLight, doitGreen], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: doitGreen.opacity(0.5), radius: 18)
                    Text("DO IT").font(.system(size: 60, weight: .black))
                    Text("Take back your time.")
                        .font(.title2.weight(.bold)).foregroundColor(doitGreen)
                    Text("Pick the apps that waste your time. You get \(Limit.minutes) minutes a day on them. Once that's used up, they stay locked until tomorrow.")
                        .foregroundColor(.secondary)
                }
                .padding(.top, 12)

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
                .opacity(allowed ? 1 : 0.5)

                if let problem { Text(problem).foregroundColor(doitRed) }

                Button {
                    Blocker.selection = selection
                    Limit.pendingSelection = nil
                    Limit.newDay()
                    finished()
                } label: {
                    Label("Start", systemImage: "arrow.right")
                }
                .buttonStyle(BigButton(height: 60))
                .disabled(!allowed || Blocker.isEmpty(selection))
            }
            .padding(24)
        }
        .background(GlowBackground())
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
        Card {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(done ? doitGreen : Color.white.opacity(0.1))
                    if done {
                        Image(systemName: "checkmark").font(.system(size: 15, weight: .black)).foregroundColor(.black)
                    } else {
                        Text("\(number)").font(.system(size: 16, weight: .black)).foregroundColor(.white)
                    }
                }
                .frame(width: 34, height: 34)
                Text(title).font(.title3.bold())
            }
            Text(detail).foregroundColor(.secondary)
            if done && number == 1 {
                Label("Done", systemImage: "checkmark.circle.fill").foregroundColor(doitGreen).bold()
            } else {
                Button(button, action: action).buttonStyle(SoftButton())
                if done { Label("Done", systemImage: "checkmark.circle.fill").foregroundColor(doitGreen).bold() }
            }
        }
    }
}

// MARK: - Home

func clock(_ seconds: Int) -> String {
    seconds >= 3600
        ? String(format: "%d:%02d:%02d", seconds / 3600, seconds % 3600 / 60, seconds % 60)
        : String(format: "%d:%02d", seconds / 60, seconds % 60)
}

struct TodayView: View {
    var change: () -> Void
    @State private var goal = Goal.text(Goal.tomorrow)
    @State private var stretching = false
    @State private var settings = false
    @State private var changeAfterSettings = false
    @AppStorage("name", store: shared) private var name = ""
    @AppStorage("layout-order", store: shared) private var layoutOrder = ""
    @AppStorage("layout-hidden", store: shared) private var layoutHidden = ""
    @AppStorage("layout-chips", store: shared) private var layoutChips = true
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
            VStack(alignment: .leading, spacing: 18) {
                header

                todayCard
                // Shortcuts under the ring: each jumps to its settings below.
                if layoutChips {
                    HStack(spacing: 10) {
                        if shown.contains("focus") {
                            chip("scope", "Focus", Focus.active ? "On now" : "Lock now") { withAnimation { scroll.scrollTo("focus", anchor: .center) } }
                        }
                        if shown.contains("bedtime") {
                            chip("moon.fill", "Bedtime", bedtime ? "10 PM" : "Off") { withAnimation { scroll.scrollTo("bedtime", anchor: .center) } }
                        }
                        if shown.contains("alarm") {
                            chip("alarm.fill", "Alarm", alarmOn ? alarmTime.formatted(date: .omitted, time: .shortened) : "Off") { withAnimation { scroll.scrollTo("alarm", anchor: .center) } }
                        }
                        chip("figure.flexibility", "Stretch", "Morning") { stretching = true }
                    }
                }
                // The cards, in the order the person picked in Settings > Home screen.
                ForEach(shown, id: \.self) { homeCard($0).id($0) }

                Button(action: change) {
                    Label("Change apps", systemImage: "square.grid.2x2.fill")
                }
                .buttonStyle(SoftButton())
                if Limit.hasPending {
                    Text("Your app changes start tomorrow.").font(.footnote).foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(20)
        }
        }
        .background(GlowBackground(color: Limit.lockedToday ? doitRed : doitGreen))
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
        // Open the app picker only after Settings has closed, or iPhone won't show it.
        .sheet(isPresented: $settings, onDismiss: {
            if changeAfterSettings { changeAfterSettings = false; change() }
        }) { SettingsView(change: { changeAfterSettings = true; settings = false }) }
        .alert(problem ?? "", isPresented: Binding(get: { problem != nil }, set: { if !$0 { problem = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }

    private var shown: [String] { Layout.shown(order: layoutOrder, hidden: layoutHidden) }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: now)
        let part = hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening"
        return name.isEmpty ? part : "\(part), \(name)"
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                Text("DO IT").font(.system(size: 34, weight: .black))
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                    Text("\(Limit.streak)").monospacedDigit()
                }
                .font(.headline.weight(.heavy)).foregroundColor(.black)
                .padding(.horizontal, 14).frame(height: 40)
                .background(LinearGradient(colors: [doitGreenLight, doitGreen], startPoint: .top, endPoint: .bottom))
                .clipShape(Capsule())
                .shadow(color: doitGreen.opacity(0.4), radius: 10)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(Limit.streak) day streak")
                Button { settings = true } label: {
                    Image(systemName: "gearshape.fill").font(.title3).foregroundColor(.white)
                        .frame(width: 40, height: 40).background(Color.white.opacity(0.1)).clipShape(Circle())
                }
                .accessibilityLabel("Settings")
            }
            Text(greeting).font(.title3.weight(.semibold)).foregroundColor(.secondary)
        }
    }

    @ViewBuilder private func homeCard(_ id: String) -> some View {
        switch id {
        case "focus": focusCard
        case "goal": goalCard
        case "opens": opensCard
        case "week": weekCard
        case "bedtime": bedtimeCard
        case "alarm": alarmCard
        default: EmptyView()
        }
    }

    private var goalCard: some View {
        Card {
            CardHeader(icon: "target", title: "TOMORROW'S GOAL")
            if !Goal.today.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill").foregroundColor(doitGreen)
                    Text("Today: \(Goal.today)").bold()
                }
            }
            Text("What do you want to get done tomorrow?").font(.headline)
            TextField("Finish my essay", text: $goal)
                .padding(.horizontal, 14).frame(height: 48)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .onChange(of: goal) { Goal.save($0.trimmingCharacters(in: .whitespaces), Goal.tomorrow) }
            Text("It shows up on your alarm in the morning.").font(.footnote).foregroundColor(.secondary)
        }
    }

    /// App checker: how many times each app was opened today. iPhone only lets
    /// DO IT show this inside a Screen Time report, so the numbers are drawn by the report.
    private var opensCard: some View {
        Card {
            CardHeader(icon: "hand.tap.fill", title: "APP CHECKER")
            Text("How many times you picked up your phone to use each app today.").foregroundColor(.secondary)
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
            CardHeader(icon: "chart.bar.fill", title: "THIS WEEK") {
                Text("\(mins.reduce(0, +)) min").font(.subheadline.weight(.bold)).foregroundColor(.secondary)
            }
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(0..<7, id: \.self) { i in
                    let over = mins[i] >= Limit.minutes
                    VStack(spacing: 8) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(LinearGradient(colors: over ? [doitRed, doitRed.opacity(0.6)] : [doitGreenLight, doitGreenDark],
                                                     startPoint: .top, endPoint: .bottom))
                                .frame(height: max(6, CGFloat(min(mins[i], Limit.minutes)) / CGFloat(Limit.minutes) * 110))
                        }
                        .frame(height: 110)
                        Text(weekday.string(from: days[i])).font(.caption.weight(.heavy))
                            .foregroundColor(i == 6 ? .black : .secondary)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(i == 6 ? doitGreen : .clear))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            if let best {
                Text("Best day: \(longDay.string(from: best.0)), with \(best.1) min.")
                    .font(.footnote).foregroundColor(.secondary)
            }
        }
    }

    private func chip(_ icon: String, _ title: String, _ detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 20, weight: .bold)).foregroundColor(doitGreen)
                    .frame(height: 24)
                Text(title).font(.subheadline.weight(.bold)).foregroundColor(.white)
                Text(detail).font(.caption).foregroundColor(.secondary).lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(Color.white.opacity(0.07))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.09)))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var todayCard: some View {
        if !Limit.lockedToday {
            // One big glowing ring for the time left today.
            let used = Limit.usedToday
            VStack(spacing: 22) {
                TimeRing(left: Limit.minutes - used, total: Limit.minutes)
                    .frame(width: 250, height: 250)
                    .padding(.top, 10)
                HStack(spacing: 0) {
                    Stat(value: "\(used)m", label: "Used")
                    Divider().frame(height: 30).overlay(Color.white.opacity(0.15))
                    Stat(value: "\(Limit.minutes)m", label: "Daily limit")
                    Divider().frame(height: 30).overlay(Color.white.opacity(0.15))
                    Stat(value: "\(Limit.streak)", label: Limit.streak == 1 ? "Day streak" : "Days streak")
                }
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .frame(maxWidth: .infinity)
        } else {
            let midnight = Calendar.current.startOfDay(for: now).addingTimeInterval(86400)
            Card {
                CardHeader(icon: "lock.fill", title: "DONE FOR TODAY", color: doitRed)
                Text(clock(max(0, Int(midnight.timeIntervalSince(now)))))
                    .font(.system(size: 56, weight: .black, design: .rounded).monospacedDigit())
                    .foregroundColor(doitRed)
                Text("You used all \(Limit.minutes) minutes. Your apps unlock at midnight.")
                    .foregroundColor(.secondary)
            }
        }
    }

    private var focusCard: some View {
        Card {
            CardHeader(icon: "scope", title: "FOCUS MODE")
            if Focus.active {
                Text(clock(max(0, Int(Focus.endsAt.timeIntervalSince(now)))))
                    .font(.system(size: 52, weight: .black, design: .rounded).monospacedDigit()).foregroundColor(doitGreen)
                Text("Your apps are locked. Go get it done.").foregroundColor(.secondary)
            } else {
                Text("Lock your apps right now. Once it starts, it can't be stopped.").foregroundColor(.secondary)
                HStack(spacing: 10) {
                    ForEach(Focus.choices, id: \.self) { m in
                        Button { askFocus = m } label: {
                            Text(m < 60 ? "\(m)m" : "\(m / 60)h")
                        }
                        .buttonStyle(BigButton(height: 48))
                    }
                }
            }
        }
    }

    private var alarmCard: some View {
        Card {
            CardHeader(icon: "alarm.fill", title: "MORNING ALARM") {
                Toggle("Morning alarm", isOn: Binding(get: { alarmOn }, set: { want in
                    if !want && MorningAlarm.ringing {
                        problem = "The alarm can't be turned off while it's going off. Take a picture of the sink."
                        return
                    }
                    alarmOn = want
                    MorningAlarm.on = want
                    Task { await MorningAlarm.reschedule() }
                }))
                .labelsHidden()
                .tint(doitGreen)
            }
            Text("Goes off every few minutes, with no snooze, until you get up and take a picture of the sink.")
                .foregroundColor(.secondary)
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
                .font(.caption2).foregroundColor(.secondary.opacity(0.7))
        }
    }

    private var bedtimeCard: some View {
        Card {
            CardHeader(icon: "moon.fill", title: "BEDTIME LOCK") {
                Toggle("Bedtime lock", isOn: Binding(get: { bedtime }, set: { want in
                    if want {
                        do { try Bedtime.turnOn(); bedtime = true } catch { problem = "Bedtime lock couldn't turn on. Try again in a moment." }
                    } else if Bedtime.isNight {
                        problem = "Bedtime lock can only be turned off during the day."
                    } else {
                        Bedtime.turnOff(); bedtime = false
                    }
                }))
                .labelsHidden()
                .tint(doitGreen)
            }
            Text("Locks your apps every night from 10 PM to 7 AM.").foregroundColor(.secondary)
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
            CardHeader(icon: "square.grid.2x2.fill", title: "CHANGE APPS")
            Text("Change apps").font(.largeTitle.weight(.black))
            Text("Changes start tomorrow, so they can't be used to get more time today.")
                .foregroundColor(.secondary)
            Button("Pick apps") { picking = true }
                .buttonStyle(SoftButton())
            Spacer()
            Button("Save for tomorrow") {
                Limit.pendingSelection = selection
                dismiss()
            }
            .buttonStyle(BigButton())
            .disabled(Blocker.isEmpty(selection))
            Button("Cancel") { dismiss() }.foregroundColor(.white).frame(maxWidth: .infinity)
        }
        .padding(24)
        .background(GlowBackground())
        .preferredColorScheme(.dark)
        .familyActivityPicker(isPresented: $picking, selection: $selection)
    }
}
