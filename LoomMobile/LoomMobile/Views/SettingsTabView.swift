import SwiftUI
import LoomKit

struct SettingsTabView: View {
    let appState: MobileAppState
    @AppStorage("appearance") private var appearance = "system"

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                List {
                    Section("Categories") {
                        if let config = appState.categoryConfig {
                            ForEach(config.orderedCategoryNames, id: \.self) { name in
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(CategoryColors.color(for: name))
                                        .frame(width: 10, height: 10)
                                    Text(name)
                                        .foregroundStyle(Theme.textPrimary)
                                }
                            }
                        }
                    }

                    Section("Appearance") {
                        Picker("Theme", selection: $appearance) {
                            Text("System").tag("system")
                            Text("Light").tag("light")
                            Text("Dark").tag("dark")
                        }
                    }

                    Section("About") {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
