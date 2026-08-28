import SwiftUI
import Charts

struct BudgetOverviewView: View {
    @Bindable var viewModel: BudgetViewModel
    @State private var analyticsViewModel: AnalyticsViewModel?
    @State private var selectedTab: Int = 0 // 0 = Analytics, 1 = Budgets
    @State private var showEditBudget = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented Hub Picker
                Picker("View Mode", selection: $selectedTab) {
                    Text("Charts & Insights").tag(0)
                    Text("Budget Limits").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)

                ScrollView {
                    VStack(spacing: 20) {
                        if selectedTab == 0 {
                            // MARK: - Analytics & Visualizations Tab
                            if let analyticsVM = analyticsViewModel {
                                analyticsSection(analyticsVM)
                            } else {
                                ProgressView()
                                    .padding(.top, 40)
                            }
                        } else {
                            // MARK: - Budget Limits Tab
                            budgetSection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle(selectedTab == 0 ? "Analytics & Trends" : "Monthly Budget")
            .toolbar {
                if selectedTab == 1 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showEditBudget = true
                        } label: {
                            Image(systemName: "pencil.circle")
                                .font(.title3)
                                .foregroundStyle(.appAccent)
                        }
                    }
                }
            }
            .sheet(isPresented: $showEditBudget, onDismiss: {
                Task {
                    await viewModel.loadData()
                    await analyticsViewModel?.loadData()
                }
            }) {
                EditBudgetSheet(viewModel: viewModel)
            }
            .refreshable {
                await reloadAll()
            }
            .task {
                if analyticsViewModel == nil {
                    // Create analytics view model with the same firestore service and userId
                    analyticsViewModel = AnalyticsViewModel(
                        firestoreService: viewModel.firestoreService,
                        userId: viewModel.userId
                    )
                }
                await reloadAll()
            }
        }
    }

    private func reloadAll() async {
        async let b = viewModel.loadData()
        async let a = analyticsViewModel?.loadData()
        _ = await (b, a)
    }

    // MARK: - Analytics Section

    @ViewBuilder
    private func analyticsSection(_ aVM: AnalyticsViewModel) -> some View {
        if aVM.isLoading && aVM.expenses.isEmpty {
            ProgressView()
                .padding(.top, 60)
        } else {
            // Month Selector
            analyticsMonthSelector(aVM)

            // Spending Summary Card
            analyticsSummaryCard(aVM)

            // Category Breakdown (Donut Chart)
            if !aVM.categoryBreakdown.isEmpty {
                categoryDonutChartCard(aVM)
            }

            // Daily Spending Trend (Bar Chart)
            if !aVM.expenses.isEmpty {
                dailySpendingBarChartCard(aVM)
            }

            // Day of Week Pattern
            if !aVM.expenses.isEmpty {
                dayOfWeekPatternCard(aVM)
            }

            // Smart Student Insights
            if !aVM.expenses.isEmpty {
                studentInsightsCard(aVM)
            }

            if aVM.expenses.isEmpty {
                emptyAnalyticsView
            }
        }
    }

    private func analyticsMonthSelector(_ aVM: AnalyticsViewModel) -> some View {
        HStack {
            Button {
                aVM.goToPreviousMonth()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(aVM.displayMonth)
                .font(.headline)

            Spacer()

            Button {
                aVM.goToNextMonth()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(aVM.isCurrentMonth ? .quaternary : .secondary)
            }
            .disabled(aVM.isCurrentMonth)
        }
        .padding(.horizontal, 4)
    }

    private func analyticsSummaryCard(_ aVM: AnalyticsViewModel) -> some View {
        VStack(spacing: 12) {
            Text("TOTAL SPENT")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(1)

            Text(CurrencyFormatter.format(aVM.totalSpent))
                .font(.system(size: 38, weight: .bold, design: .rounded).monospacedDigit())

            HStack(spacing: 16) {
                VStack(spacing: 2) {
                    Text("Daily Average")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatter.format(aVM.dailyAverage))
                        .font(.subheadline.bold().monospacedDigit())
                }

                Divider().frame(height: 24)

                VStack(spacing: 2) {
                    Text("Projected Total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatter.format(aVM.projectedMonthlyTotal))
                        .font(.subheadline.bold().monospacedDigit())
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Donut Chart Card

    private func categoryDonutChartCard(_ aVM: AnalyticsViewModel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SPENDING BY CATEGORY")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(1)

            // Swift Charts Donut
            Chart(aVM.categoryBreakdown) { slice in
                SectorMark(
                    angle: .value("Amount", NSDecimalNumber(decimal: slice.amount).doubleValue),
                    innerRadius: .ratio(0.62),
                    angularInset: 1.5
                )
                .cornerRadius(4)
                .foregroundStyle(slice.color)
            }
            .frame(height: 200)
            .chartBackground { _ in
                VStack(spacing: 2) {
                    Text("Top Category")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let top = aVM.categoryBreakdown.first {
                        Text(top.name)
                            .font(.caption.bold())
                            .lineLimit(1)
                        Text(String(format: "%.0f%%", top.percentage))
                            .font(.title3.bold())
                            .foregroundStyle(top.color)
                    }
                }
            }

            // Category breakdown rows
            VStack(spacing: 8) {
                ForEach(aVM.categoryBreakdown) { slice in
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(slice.color.opacity(0.18))
                                .frame(width: 32, height: 32)
                            Image(systemName: slice.icon)
                                .font(.caption)
                                .foregroundStyle(slice.color)
                        }

                        Text(slice.name)
                            .font(.subheadline.weight(.medium))

                        Spacer()

                        VStack(alignment: .trailing, spacing: 1) {
                            Text(CurrencyFormatter.format(slice.amount))
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                            Text(String(format: "%.1f%%", slice.percentage))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(18)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Daily Spending Bar Chart

    private func dailySpendingBarChartCard(_ aVM: AnalyticsViewModel) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("DAILY SPENDING")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(1)

                Spacer()

                Text("Avg: \(CurrencyFormatter.format(aVM.dailyAverage))")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Chart {
                ForEach(aVM.dailySpendingPoints) { pt in
                    BarMark(
                        x: .value("Day", pt.day),
                        y: .value("Amount", pt.amount)
                    )
                    .foregroundStyle(Color.appAccent.gradient)
                    .cornerRadius(3)
                }

                // Daily Average Line
                RuleMark(
                    y: .value("Average", NSDecimalNumber(decimal: aVM.dailyAverage).doubleValue)
                )
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .foregroundStyle(.orange)
            }
            .frame(height: 180)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let day = value.as(Int.self) {
                            Text("\(day)")
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let amt = value.as(Double.self) {
                            Text("$\(Int(amt))")
                                .font(.caption2)
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Day of Week Pattern Card

    private func dayOfWeekPatternCard(_ aVM: AnalyticsViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SPENDING BY DAY OF WEEK")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(1)

            Chart(aVM.dayOfWeekStats) { stat in
                BarMark(
                    x: .value("Total", NSDecimalNumber(decimal: stat.total).doubleValue),
                    y: .value("Day", stat.dayName)
                )
                .foregroundStyle(stat.dayName == aVM.topSpendingDayOfWeek ? Color.appAccent : Color.secondary.opacity(0.4))
                .cornerRadius(4)
            }
            .frame(height: 160)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.caption)
                }
            }

            if let topDay = aVM.topSpendingDayOfWeek {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(.appAccent)
                    Text("You spend the most on **\(topDay)s**.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding(18)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Student Insights Card

    private func studentInsightsCard(_ aVM: AnalyticsViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("STUDENT FINANCIAL INSIGHTS")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(1)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                insightTile(
                    title: "Coffee vs Groceries",
                    value: "\(CurrencyFormatter.format(aVM.coffeeSpent)) / \(CurrencyFormatter.format(aVM.groceriesSpent))",
                    subtitle: aVM.coffeeSpent > aVM.groceriesSpent ? "⚠️ Coffee > Groceries!" : "Balanced grocery ratio",
                    icon: "cup.and.saucer.fill",
                    color: .orange
                )

                insightTile(
                    title: "PRESTO Card Balance",
                    value: CurrencyFormatter.format(aVM.prestoBalance),
                    subtitle: aVM.prestoTransitRidesCount > 0 ? "\(aVM.prestoTransitRidesCount) card taps this month" : "Stored value balance",
                    icon: "tram.circle.fill",
                    color: .green
                )

                if let largest = aVM.largestExpense {
                    insightTile(
                        title: "Largest Purchase",
                        value: CurrencyFormatter.format(largest.decimalAmount),
                        subtitle: largest.merchant.isEmpty ? "Single Expense" : largest.merchant,
                        icon: "arrow.up.right.circle.fill",
                        color: .red
                    )
                }

                insightTile(
                    title: "Daily Burn Rate",
                    value: "\(CurrencyFormatter.format(aVM.dailyAverage))/day",
                    subtitle: "Target runway",
                    icon: "flame.fill",
                    color: .purple
                )
            }
        }
        .padding(18)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func insightTile(title: String, value: String, subtitle: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Spacer()
            }

            Text(value)
                .font(.subheadline.bold().monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(12)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var emptyAnalyticsView: some View {
        VStack(spacing: 14) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("No Spending Yet This Month")
                .font(.headline)
            Text("Add transactions to unlock charts, category breakdowns, and student insights.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }

    // MARK: - Budget Section

    private var budgetSection: some View {
        VStack(spacing: 20) {
            if viewModel.isLoading {
                ProgressView().padding(.top, 40)
            } else {
                // Overall budget card
                overallBudgetCard

                // Category budgets
                if !viewModel.categoryBudgets.isEmpty {
                    categoryBudgetsSection
                }

                if viewModel.categoryBudgets.isEmpty && viewModel.overallLimit == nil {
                    emptyBudgetState
                }
            }
        }
    }

    private var overallBudgetCard: some View {
        VStack(spacing: 20) {
            Text(viewModel.displayMonth)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if let limit = viewModel.overallLimit {
                ProgressRing(
                    progress: viewModel.overallProgress,
                    lineWidth: 14,
                    size: 150,
                    isOverBudget: viewModel.overallProgress > 1.0
                ) {
                    VStack(spacing: 2) {
                        Text(CurrencyFormatter.format(viewModel.totalSpent))
                            .font(.title3.bold().monospacedDigit())
                        Text("of \(CurrencyFormatter.format(limit))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                if let remaining = viewModel.overallRemaining {
                    if remaining >= 0 {
                        Text("\(CurrencyFormatter.format(remaining)) remaining")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.appAccent)
                    } else {
                        Text("\(CurrencyFormatter.format(abs(remaining))) over budget")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.appWarning)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Text(CurrencyFormatter.format(viewModel.totalSpent))
                        .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
                    Text("spent this month")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Set a Monthly Budget") {
                        showEditBudget = true
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.appAccent)
                    .padding(.top, 4)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var categoryBudgetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("CATEGORY TARGETS")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(1)

                Spacer()

                Button("Edit Targets") {
                    showEditBudget = true
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.appAccent)
            }

            VStack(spacing: 8) {
                ForEach(viewModel.categoryBudgets) { info in
                    CategoryBudgetRow(info: info)
                }
            }
        }
    }

    private var emptyBudgetState: some View {
        VStack(spacing: 14) {
            Image(systemName: "chart.pie")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("No Budget Limits Set")
                .font(.headline)
            Text("Set overall and category spending limits to keep your student expenses on track.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Set Budget") {
                showEditBudget = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.appAccent)
        }
        .padding(32)
    }
}

// MARK: - Category Budget Row

struct CategoryBudgetRow: View {
    let info: BudgetViewModel.CategoryBudgetInfo

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: info.colorHex).opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: info.icon)
                        .font(.caption)
                        .foregroundStyle(Color(hex: info.colorHex))
                }

                Text(info.name)
                    .font(.subheadline.weight(.medium))

                Spacer()

                if let limit = info.limit {
                    Text("\(CurrencyFormatter.format(info.spent)) / \(CurrencyFormatter.format(limit))")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(info.isOverBudget ? .appWarning : .secondary)
                } else {
                    Text(CurrencyFormatter.format(info.spent))
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if info.limit != nil {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.secondary.opacity(0.15))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(info.isOverBudget ? Color.appWarning : Color(hex: info.colorHex))
                            .frame(width: geometry.size.width * min(CGFloat(info.progress), 1.0), height: 6)
                            .animation(.spring(response: 0.6), value: info.progress)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Edit Budget Sheet

struct EditBudgetSheet: View {
    @Bindable var viewModel: BudgetViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Overall Monthly Budget") {
                    HStack {
                        Text("$")
                            .foregroundStyle(.secondary)
                        TextField("2,000", text: $viewModel.overallLimitText)
                            .keyboardType(.decimalPad)
                    }
                }

                Section("Category Spending Limits") {
                    ForEach(viewModel.categories.filter { !$0.isArchived }) { category in
                        if let catId = category.id {
                            HStack {
                                Image(systemName: category.icon)
                                    .foregroundStyle(category.color)
                                    .frame(width: 24)
                                Text(category.name)
                                Spacer()
                                HStack {
                                    Text("$")
                                        .foregroundStyle(.secondary)
                                    TextField("—", text: Binding(
                                        get: { viewModel.categoryLimitTexts[catId] ?? "" },
                                        set: { viewModel.categoryLimitTexts[catId] = $0 }
                                    ))
                                    .keyboardType(.decimalPad)
                                    .frame(width: 80)
                                    .multilineTextAlignment(.trailing)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel.saveBudget()
                            await viewModel.loadData()
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.appAccent)
                    .disabled(viewModel.isSaving)
                }
            }
        }
    }
}
