import SwiftUI

struct SemesterBudgetCard: View {
    let spentThisSemester: Decimal
    var onConfigure: () -> Void

    @AppStorage("semesterBudgetData") private var semesterBudgetData: Data = Data()

    private var semesterBudget: SemesterBudget? {
        if let decoded = try? JSONDecoder().decode(SemesterBudget.self, from: semesterBudgetData), decoded.isEnabled {
            return decoded
        }
        return nil
    }

    var body: some View {
        if let budget = semesterBudget {
            let spent = NSDecimalNumber(decimal: spentThisSemester).doubleValue
            let daily = budget.safeDailyBudget(spentSoFar: spent)
            let remaining = budget.remainingFunds(spentSoFar: spent)
            let isOverBudget = remaining < 0

            VStack(alignment: .leading, spacing: 16) {
                // Header Row
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "graduationcap.fill")
                            .font(.title3)
                            .foregroundStyle(Color(hex: "5856D6"))

                        VStack(alignment: .leading, spacing: 1) {
                            Text(budget.termName.uppercased())
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(.secondary)
                            Text("Semester Burn Rate")
                                .font(.caption.weight(.semibold))
                        }
                    }

                    Spacer()

                    Button {
                        onConfigure()
                    } label: {
                        HStack(spacing: 4) {
                            Text("\(budget.daysRemaining) days left")
                                .font(.caption2.weight(.bold))
                            Image(systemName: "pencil")
                                .font(.system(size: 9))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(hex: "5856D6").opacity(0.12))
                        .foregroundStyle(Color(hex: "5856D6"))
                        .clipShape(Capsule())
                    }
                }

                // Daily Safe Budget Display
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("DAILY SAFE ALLOWANCE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                            .tracking(0.5)

                        Text("$\(String(format: "%.2f", daily))")
                            .font(.system(size: 32, weight: .heavy, design: .rounded).monospacedDigit())
                            .foregroundStyle(isOverBudget ? Color.appWarning : Color.appAccent)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Funds Left")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("$\(String(format: "%.0f", max(0, remaining)))")
                            .font(.headline.bold())
                    }
                }

                // Linear Pace Bar
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.primary.opacity(0.06))
                                .frame(height: 6)

                            let ratio = CGFloat(budget.progressRatio(spentSoFar: spent))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    isOverBudget
                                        ? LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                                        : LinearGradient(colors: [Color(hex: "5856D6"), Color.appAccent], startPoint: .leading, endPoint: .trailing)
                                )
                                .frame(width: geo.size.width * min(ratio, 1.0), height: 6)
                        }
                    }
                    .frame(height: 6)

                    HStack {
                        Text("Day \(budget.daysElapsed) of \(budget.totalDays)")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text("Budget: $\(String(format: "%.0f", budget.totalBudget))")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(18)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
}
