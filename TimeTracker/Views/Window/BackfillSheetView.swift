import SwiftUI

struct BackfillSheetView: View {
    let date: Date
    let categories: [String]
    let onAdd: (String, Date, Date, String?) -> Void
    let onCancel: () -> Void

    @State private var selectedCategory: String
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var intention: String = ""

    init(date: Date, categories: [String], onAdd: @escaping (String, Date, Date, String?) -> Void, onCancel: @escaping () -> Void) {
        self.date = date
        self.categories = categories
        self.onAdd = onAdd
        self.onCancel = onCancel
        let cal = Calendar.current
        let now = Date()
        let dayStart = cal.startOfDay(for: date)
        let defaultStart = cal.isDate(date, inSameDayAs: now)
            ? now.addingTimeInterval(-3600)
            : dayStart.addingTimeInterval(9 * 3600)
        let defaultEnd = cal.isDate(date, inSameDayAs: now)
            ? now
            : dayStart.addingTimeInterval(10 * 3600)
        self._selectedCategory = State(initialValue: categories.first ?? "Other")
        self._startTime = State(initialValue: defaultStart)
        self._endTime = State(initialValue: defaultEnd)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Session")
                .font(.headline)

            Form {
                Picker("Category", selection: $selectedCategory) {
                    ForEach(categories, id: \.self) { cat in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(CategoryColors.color(for: cat))
                                .frame(width: 8, height: 8)
                            Text(cat)
                        }
                        .tag(cat)
                    }
                }

                DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                DatePicker("End", selection: $endTime, displayedComponents: .hourAndMinute)

                TextField("Intention (optional)", text: $intention)
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add Session") {
                    onAdd(
                        selectedCategory,
                        startTime,
                        endTime,
                        intention.isEmpty ? nil : intention
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(CategoryColors.accent)
                .disabled(endTime <= startTime)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 320)
    }
}
