import SwiftUI

struct SemesterBudgetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("semesterBudgetData") private var semesterBudgetData: Data = Data()

    @State private var termName: String = "Fall 2026"
    @State private var totalBudgetText: String = "4000"
    @State private var startDate: Date = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 1)) ?? Date()
    @State private var endDate: Date = Calendar.current.date(from: DateComponents(year: 2026, month: 12, day: 20)) ?? Date()
    @State private var isEnabled: Bool = true

    private let presetTerms = ["Fall 2026", "Winter 2027", "Summer 2027", "Full Year 2026-27", "Custom Term"]

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Enable Toggle
                Section {
                    Toggle("Enable Semester Budgeting", isOn: $isEnabled)
                        .tint(Color.appAccent)
                } footer: {
                    Text("Calculates a dynamic daily safe-to-spend allowance from lump-sum student loans, OSAP, or savings across your academic term.")
                }

                if isEnabled {
                    // MARK: - Term Selection
                    Section("Academic Term") {
                        Picker("Select Term", selection: $termName) {
                            ForEach(presetTerms, id: \.self) { term in
                                Text(term).tag(term)
                            }
                        }

                        if termName == "Custom Term" {
                            TextField("Term Name (e.g. Co-op Term)", text: $termName)
                        }

                        DatePicker("Term Start", selection: $startDate, displayedComponents: .date)
                        DatePicker("Term End", selection: $endDate, displayedComponents: .date)
                    }

                    // MARK: - Lump Sum Funds
                    Section {
                        HStack {
                            Text("$")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            TextField("4000.00", text: $totalBudgetText)
                                .keyboardType(.decimalPad)
                                .font(.headline)
                        }
                    } header: {
                        Text("Total Available Funds (Lump Sum)")
                    } footer: {
                        let days = max(1, Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 110)
                        let budget = Double(totalBudgetText) ?? 0
                        let daily = days > 0 ? budget / Double(days) : 0
                        Text("Duration: \(days) days. Initial target pace: $\(String(format: "%.2f", daily))/day.")
                    }
                }
            }
            .navigationTitle("Semester Budget Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveBudget()
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(Color.appAccent)
                }
            }
            .onAppear {
                loadExistingBudget()
            }
        }
    }

    private func loadExistingBudget() {
        if let decoded = try? JSONDecoder().decode(SemesterBudget.self, from: semesterBudgetData) {
            termName = decoded.termName
            totalBudgetText = String(format: "%.0f", decoded.totalBudget)
            startDate = decoded.startDate
            endDate = decoded.endDate
            isEnabled = decoded.isEnabled
        }
    }

    private func saveBudget() {
        let budget = SemesterBudget(
            termName: termName,
            startDate: startDate,
            endDate: endDate,
            totalBudget: Double(totalBudgetText) ?? 4000.0,
            isEnabled: isEnabled
        )
        if let encoded = try? JSONEncoder().encode(budget) {
            semesterBudgetData = encoded
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(.success)
        }
    }
}
