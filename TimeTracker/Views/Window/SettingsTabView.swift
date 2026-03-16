import SwiftUI
import ServiceManagement

enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General"
    case notification = "Notification"
    case calendar = "Calendar"
    case category = "Category"
    case window = "Window"
    case browser = "Browser Tracking"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .notification: return "bell"
        case .calendar: return "calendar"
        case .category: return "tag"
        case .window: return "macwindow"
        case .browser: return "globe"
        }
    }
}

struct SettingsTabView: View {
    @State private var config: CategoryConfig
    @State private var selectedSection: SettingsSection = .general
    @State private var selectedCategory: String?
    @State private var newCategoryName = ""
    @State private var newAppBundleId = ""
    @State private var newRelatedBundleId = ""
    @State private var newUrlPattern = ""
    @State private var showingSaveConfirmation = false

    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("showMenuBarText") private var showMenuBarText = true
    @AppStorage("goalCategory") private var goalCategory = "Coding"
    @AppStorage("goalHours") private var goalHours = 0.0

    let onSave: (CategoryConfig) -> Void

    init(config: CategoryConfig, onSave: @escaping (CategoryConfig) -> Void) {
        self._config = State(initialValue: config)
        self.onSave = onSave
    }

    private var sortedCategories: [(String, CategoryRule)] {
        config.categories.sorted { $0.key < $1.key }
    }

    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                // Sidebar
                List(SettingsSection.allCases, selection: $selectedSection) { section in
                    Label(section.rawValue, systemImage: section.icon)
                        .tag(section)
                }
                .listStyle(.sidebar)
                .frame(minWidth: 150, maxWidth: 180)

                // Detail
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        switch selectedSection {
                        case .general:
                            generalSection
                        case .notification:
                            placeholderSection("Notification settings coming soon.")
                        case .calendar:
                            placeholderSection("Calendar integration settings coming soon.")
                        case .category:
                            categorySection
                        case .window:
                            windowSection
                        case .browser:
                            placeholderSection("Browser tracking settings coming soon.")
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            // Bottom save bar
            Divider()
            HStack {
                if showingSaveConfirmation {
                    Text("Saved!")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
                Spacer()
                Button("Save") {
                    onSave(config)
                    showingSaveConfirmation = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showingSaveConfirmation = false
                    }
                }
                .keyboardShortcut("s", modifiers: .command)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
        }
    }

    // MARK: - General

    @ViewBuilder
    private var generalSection: some View {
        Text("General")
            .font(.title2.weight(.semibold))

        GroupBox("Appearance") {
            Picker("Theme", selection: $appearance) {
                Text("Light").tag("light")
                Text("Dark").tag("dark")
                Text("System").tag("system")
            }
            .pickerStyle(.segmented)
            .padding(4)
        }

        GroupBox("Menu Bar") {
            Toggle("Show timer text in menu bar", isOn: $showMenuBarText)
                .padding(4)
        }

        GroupBox("Focus Goal") {
            VStack(alignment: .leading, spacing: 8) {
                Picker("Category", selection: $goalCategory) {
                    ForEach(Array(config.categories.keys.sorted()), id: \.self) { name in
                        Text(name).tag(name)
                    }
                }

                HStack {
                    Text("Daily target")
                    Stepper(
                        value: $goalHours,
                        in: 0...12,
                        step: 0.5
                    ) {
                        Text(goalHours > 0 ? String(format: "%.1fh", goalHours) : "Off")
                    }
                }
            }
            .padding(4)
        }
    }

    // MARK: - Category

    @ViewBuilder
    private var categorySection: some View {
        Text("Categories")
            .font(.title2.weight(.semibold))

        HSplitView {
            // Category list
            VStack(alignment: .leading, spacing: 0) {
                List(selection: $selectedCategory) {
                    ForEach(sortedCategories, id: \.0) { name, _ in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(CategoryColors.color(for: name))
                                .frame(width: 8, height: 8)
                            Text(name)
                        }
                        .tag(name)
                    }
                }
                .listStyle(.sidebar)

                Divider()

                HStack(spacing: 4) {
                    TextField("New category", text: $newCategoryName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addCategory() }
                    Button(action: addCategory) {
                        Image(systemName: "plus")
                    }
                    .disabled(newCategoryName.isEmpty)
                    Button(action: removeSelectedCategory) {
                        Image(systemName: "minus")
                    }
                    .disabled(selectedCategory == nil)
                }
                .padding(8)
            }
            .frame(minWidth: 140, maxWidth: 180)

            // Category detail
            if let name = selectedCategory, let rule = config.categories[name] {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(name)
                            .font(.headline)

                        GroupBox("Primary Apps") {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(rule.apps, id: \.self) { app in
                                    HStack {
                                        Text(app)
                                            .font(.system(.body, design: .monospaced))
                                        Spacer()
                                        Button(action: { removeApp(app, from: name) }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                HStack(spacing: 4) {
                                    TextField("Bundle ID", text: $newAppBundleId)
                                        .textFieldStyle(.roundedBorder)
                                        .onSubmit { addApp(to: name) }
                                    Button("Add") { addApp(to: name) }
                                        .disabled(newAppBundleId.isEmpty)
                                }
                                .padding(.top, 4)
                            }
                            .padding(4)
                        }

                        GroupBox("Related Apps") {
                            VStack(alignment: .leading, spacing: 4) {
                                if let related = rule.related, !related.isEmpty {
                                    ForEach(related, id: \.self) { app in
                                        HStack {
                                            Text(app)
                                                .font(.system(.body, design: .monospaced))
                                            Spacer()
                                            Button(action: { removeRelated(app, from: name) }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundStyle(.secondary)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                } else {
                                    Text("None")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                HStack(spacing: 4) {
                                    TextField("Bundle ID", text: $newRelatedBundleId)
                                        .textFieldStyle(.roundedBorder)
                                        .onSubmit { addRelated(to: name) }
                                    Button("Add") { addRelated(to: name) }
                                        .disabled(newRelatedBundleId.isEmpty)
                                }
                                .padding(.top, 4)
                            }
                            .padding(4)
                        }

                        GroupBox("URL Patterns") {
                            VStack(alignment: .leading, spacing: 4) {
                                if let patterns = rule.urlPatterns, !patterns.isEmpty {
                                    ForEach(patterns, id: \.self) { pattern in
                                        HStack {
                                            Text(pattern)
                                                .font(.system(.body, design: .monospaced))
                                            Spacer()
                                            Button(action: { removeUrlPattern(pattern, from: name) }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundStyle(.secondary)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                } else {
                                    Text("None")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                HStack(spacing: 4) {
                                    TextField("URL pattern", text: $newUrlPattern)
                                        .textFieldStyle(.roundedBorder)
                                        .onSubmit { addUrlPattern(to: name) }
                                    Button("Add") { addUrlPattern(to: name) }
                                        .disabled(newUrlPattern.isEmpty)
                                }
                                .padding(.top, 4)
                            }
                            .padding(4)
                        }
                    }
                    .padding(12)
                }
            } else {
                VStack {
                    Spacer()
                    Text("Select a category")
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(minHeight: 300)
    }

    // MARK: - Window

    @ViewBuilder
    private var windowSection: some View {
        Text("Window")
            .font(.title2.weight(.semibold))

        GroupBox("Startup") {
            Toggle("Launch at login", isOn: Binding(
                get: { SMAppService.mainApp.status == .enabled },
                set: { newValue in
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        print("Failed to toggle launch at login: \(error)")
                    }
                }
            ))
            .padding(4)
        }
    }

    // MARK: - Placeholder

    @ViewBuilder
    private func placeholderSection(_ text: String) -> some View {
        VStack {
            Spacer()
            Text(text)
                .foregroundStyle(Theme.textTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func addCategory() {
        let name = newCategoryName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, config.categories[name] == nil else { return }
        config.categories[name] = CategoryRule(apps: [], related: nil, urlPatterns: nil)
        selectedCategory = name
        newCategoryName = ""
    }

    private func removeSelectedCategory() {
        guard let name = selectedCategory else { return }
        config.categories.removeValue(forKey: name)
        selectedCategory = sortedCategories.first?.0
    }

    private func addApp(to category: String) {
        let bundleId = newAppBundleId.trimmingCharacters(in: .whitespaces)
        guard !bundleId.isEmpty else { return }
        config.categories[category]?.apps.append(bundleId)
        newAppBundleId = ""
    }

    private func removeApp(_ app: String, from category: String) {
        config.categories[category]?.apps.removeAll { $0 == app }
    }

    private func addRelated(to category: String) {
        let bundleId = newRelatedBundleId.trimmingCharacters(in: .whitespaces)
        guard !bundleId.isEmpty else { return }
        if config.categories[category]?.related == nil {
            config.categories[category]?.related = []
        }
        config.categories[category]?.related?.append(bundleId)
        newRelatedBundleId = ""
    }

    private func removeRelated(_ app: String, from category: String) {
        config.categories[category]?.related?.removeAll { $0 == app }
        if config.categories[category]?.related?.isEmpty == true {
            config.categories[category]?.related = nil
        }
    }

    private func addUrlPattern(to category: String) {
        let pattern = newUrlPattern.trimmingCharacters(in: .whitespaces)
        guard !pattern.isEmpty else { return }
        if config.categories[category]?.urlPatterns == nil {
            config.categories[category]?.urlPatterns = []
        }
        config.categories[category]?.urlPatterns?.append(pattern)
        newUrlPattern = ""
    }

    private func removeUrlPattern(_ pattern: String, from category: String) {
        config.categories[category]?.urlPatterns?.removeAll { $0 == pattern }
        if config.categories[category]?.urlPatterns?.isEmpty == true {
            config.categories[category]?.urlPatterns = nil
        }
    }
}
