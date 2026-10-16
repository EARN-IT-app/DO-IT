// Settings: a few general choices. The daily limit isn't here on purpose:
// it can't be changed, so it can't be used to get more time.
import SwiftUI

struct SettingsView: View {
    var change: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage("name", store: shared) private var name = ""
    @AppStorage("quotes", store: shared) private var quotes = true

    var body: some View {
        NavigationStack {
            Form {
                Section("General") {
                    TextField("Your name", text: $name)
                    Toggle("Motivational quotes on the lock screen", isOn: $quotes)
                    Button("Notifications and sounds") {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                    }
                }
                Section {
                    NavigationLink("Home screen layout") { LayoutView() }
                } header: {
                    Text("Home screen")
                } footer: {
                    Text("Pick which cards you see and drag them into the order you like.")
                }
                Section {
                    Button("Change the apps I block", action: change)
                } header: {
                    Text("Your limit")
                } footer: {
                    Text("You get \(Limit.minutes) minutes a day on your blocked apps. This can't be changed, so you can't give yourself more time. App changes start tomorrow.")
                }
                Section {
                    Text("Everything stays on this phone. DO IT has no accounts and doesn't send your information anywhere.")
                        .foregroundColor(.secondary)
                } header: { Text("Your data") }
                Section {
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                    Text("Alarm video: \"Just Do It\" by Shia LaBeouf, from #INTRODUCTIONS by LaBeouf, Rönkkö & Turner (2015). Played from YouTube.")
                        .font(.footnote).foregroundColor(.secondary)
                } header: { Text("About") }
            }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .tint(doitGreen)
        .preferredColorScheme(.dark)
    }
}

// Drag cards into order and turn them on or off.
struct LayoutView: View {
    @AppStorage("layout-order", store: shared) private var layoutOrder = ""
    @AppStorage("layout-hidden", store: shared) private var layoutHidden = ""
    @AppStorage("layout-chips", store: shared) private var layoutChips = true

    var body: some View {
        List {
            Section {
                Toggle("Shortcut buttons under the ring", isOn: $layoutChips)
            }
            Section {
                ForEach(Layout.order(layoutOrder), id: \.self) { id in
                    Toggle(Layout.name(id), isOn: Binding(
                        get: { !Layout.list(layoutHidden).contains(id) },
                        set: { on in
                            var hidden = Layout.list(layoutHidden).filter { $0 != id }
                            if !on { hidden.append(id) }
                            layoutHidden = hidden.joined(separator: ",")
                        }))
                }
                .onMove { from, to in
                    var order = Layout.order(layoutOrder)
                    order.move(fromOffsets: from, toOffset: to)
                    layoutOrder = order.joined(separator: ",")
                }
            } header: {
                Text("Cards")
            } footer: {
                Text("Hold the ≡ handle and drag a card up or down. Hiding a card doesn't turn it off. Your alarm and locks still work.")
            }
            Section {
                Button("Reset the layout") { layoutOrder = ""; layoutHidden = ""; layoutChips = true }
            }
        }
        // Always show the drag handles, so there's no Edit button to find first.
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Home screen layout")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Which cards the home screen shows, and in what order. Saved as comma lists.
enum Layout {
    static let all = ["focus", "homework", "goal", "opens", "week", "bedtime", "alarm"]

    static func list(_ saved: String) -> [String] { saved.split(separator: ",").map(String.init) }

    static func order(_ saved: String) -> [String] {
        let picked = list(saved).filter(all.contains)
        return picked + all.filter { !picked.contains($0) }
    }

    static func shown(order saved: String, hidden: String) -> [String] {
        let off = list(hidden)
        return order(saved).filter { !off.contains($0) }
    }

    static func name(_ id: String) -> String {
        switch id {
        case "focus": return "Focus mode"
        case "homework": return "Homework lock"
        case "goal": return "Tomorrow's goal"
        case "opens": return "App checker"
        case "week": return "This week"
        case "bedtime": return "Bedtime lock"
        case "alarm": return "Morning alarm"
        default: return id
        }
    }
}
