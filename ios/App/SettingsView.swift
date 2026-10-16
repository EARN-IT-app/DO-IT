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
