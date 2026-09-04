import SwiftUI

struct DashboardView: View {
    @Bindable var viewModel: DashboardViewModel
    var onAddExpense: () -> Void

    @State private var showPrestoTopUp = false
    @State private var showBillSplitter = false
    @State private var showSemesterBudget = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Month navigation header
                    monthHeader

                    if viewModel.isLoading {
                        DashboardSkeletonView()
                    } else {
                        // Hero Spending & Budget Card
                        heroSpendingCard

                        // Dedicated PRESTO Transit Card
                        prestoTransitCard

                        // Semester Burn-Rate Card (if enabled)
                        SemesterBudgetCard(spentThisSemester: viewModel.totalSpent) {
                            showSemesterBudget = true
                        }

                        // Student Power Tools Bar
                        studentToolsSection

                        // Top Spending Categories
                        if !viewModel.categorySpending.isEmpty {
                            categorySpendingSection
                        }

                        // Daily Pacing & Projection Stats
                        pacingStatsGrid
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onAddExpense()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.appAccent)
                    }
                }
            }
            .sheet(isPresented: $showPrestoTopUp, onDismiss: {
                Task { await viewModel.loadData() }
            }) {
                PrestoTopUpSheet(
                    firestoreService: viewModel.firestoreService,
                    userId: viewModel.userId,
                    currentBalance: viewModel.prestoBalance
                ) {
                    Task { await viewModel.loadData() }
                }
            }
            .sheet(isPresented: $showBillSplitter) {
                BillSplitterSheet { splitAmount, description in
                    onAddExpense()
                }
            }
            .sheet(isPresented: $showSemesterBudget) {
                SemesterBudgetSheet()
            }
            .refreshable {
                await viewModel.loadData()
            }
            .task {
                await viewModel.loadData()
            }
        }
    }

    // MARK: - Month Navigation Header

    private var monthHeader: some View {
        HStack {
            Button {
                viewModel.goToPreviousMonth()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Circle())
            }

            Spacer()

            Text(viewModel.displayMonth)
                .font(.headline.weight(.bold))

            Spacer()

            Button {
                viewModel.goToNextMonth()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(viewModel.isCurrentMonth ? .quaternary : .secondary)
                    .frame(width: 36, height: 36)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Circle())
            }
            .disabled(viewModel.isCurrentMonth)
        }
        .padding(.top, 4)
    }

    // MARK: - Hero Spending & Budget Card

    private var heroSpendingCard: some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                Text("TOTAL SPENT THIS MONTH")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(1)

                Text(CurrencyFormatter.format(viewModel.totalSpent))
                    .font(.system(size: 42, weight: .black, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText())
            }
            .padding(.top, 8)

            // Budget Progress Ring or Pacing Bar
            if let limit = viewModel.budgetLimit {
                VStack(spacing: 12) {
                    // Linear sleek progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.primary.opacity(0.08))
                                .frame(height: 10)

                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    viewModel.isOverBudget
                                        ? LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                                        : LinearGradient(colors: [Color(hex: "00C48C"), Color(hex: "00E5A3")], startPoint: .leading, endPoint: .trailing)
                                )
                                .frame(width: geo.size.width * min(CGFloat(viewModel.budgetProgress), 1.0), height: 10)
                                .animation(.spring(response: 0.6), value: viewModel.budgetProgress)
                        }
                    }
                    .frame(height: 10)

                    HStack {
                        if let remaining = viewModel.budgetRemaining {
                            if viewModel.isOverBudget {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(Color.appWarning)
                                    Text("\(CurrencyFormatter.format(abs(remaining))) over budget")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(Color.appWarning)
                                }
                            } else {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.appAccent)
                                    Text("\(CurrencyFormatter.format(remaining)) remaining")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(Color.appAccent)
                                }
                            }
                        }

                        Spacer()

                        Text("Limit \(CurrencyFormatter.format(limit))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    // MARK: - PRESTO Transit Card Widget

    private var prestoTransitCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Card Top Row
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "tram.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color(hex: "00C48C"))

                    VStack(alignment: .leading, spacing: 1) {
                        Text("PRESTO")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .tracking(1.5)
                            .foregroundStyle(.white)
                        Text("Transit Card")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                Spacer()

                // Contactless Wave Icon
                Image(systemName: "wave.3.forward")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.5))
            }

            // Balance Row
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CARD BALANCE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                        .tracking(0.5)

                    Text(CurrencyFormatter.format(viewModel.prestoBalance))
                        .font(.system(size: 32, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                }

                Spacer()

                // Quick Top Up Action Button
                Button {
                    showPrestoTopUp = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.caption2.bold())
                        Text("Top Up")
                            .font(.caption.weight(.bold))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Color(hex: "00C48C"))
                    .foregroundStyle(.black)
                    .clipShape(Capsule())
                    .shadow(color: Color(hex: "00C48C").opacity(0.3), radius: 6, y: 2)
                }
            }

            // Card Bottom Details
            HStack {
                if viewModel.prestoBalance > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "bus.fill")
                            .font(.caption2)
                        Text("~\(viewModel.estimatedTransitRides) TTC rides left")
                            .font(.caption2.weight(.semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.3))
                    .foregroundStyle(Color(hex: "00C48C"))
                    .clipShape(Capsule())
                } else {
                    Text("Card is empty: Top up to ride")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()

                Text("No double-counting")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [
                    Color(hex: "0F291E"),
                    Color(hex: "0A1A14"),
                    Color(hex: "06100C")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color(hex: "00C48C").opacity(0.25), lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: Color.black.opacity(0.12), radius: 10, y: 4)
    }

    // MARK: - Category Spending Section

    private var categorySpendingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("TOP CATEGORIES")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(1)

            VStack(spacing: 10) {
                let maxAmount = viewModel.categorySpending.map(\.amount).max() ?? 1
                ForEach(viewModel.categorySpending, id: \.categoryId) { item in
                    VStack(spacing: 6) {
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(hex: item.colorHex).opacity(0.15))
                                    .frame(width: 30, height: 30)
                                Image(systemName: item.icon)
                                    .font(.caption)
                                    .foregroundStyle(Color(hex: item.colorHex))
                            }

                            Text(item.name)
                                .font(.subheadline.weight(.medium))

                            Spacer()

                            Text(CurrencyFormatter.format(item.amount))
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                        }

                        // Progress proportion bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.primary.opacity(0.06))
                                    .frame(height: 4)

                                let ratio = CGFloat(NSDecimalNumber(decimal: item.amount / maxAmount).doubleValue)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(hex: item.colorHex))
                                    .frame(width: geo.size.width * min(ratio, 1.0), height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(18)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Pacing & Projection Stats Grid

    private var pacingStatsGrid: some View {
        HStack(spacing: 12) {
            pacingTile(
                title: "Daily Average",
                value: CurrencyFormatter.format(viewModel.dailyAverage),
                subtitle: "Current pace",
                icon: "calendar.badge.clock",
                color: Color.appAccent
            )

            pacingTile(
                title: "Projected Total",
                value: CurrencyFormatter.formatCompact(viewModel.projectedMonthly),
                subtitle: "Month-end estimate",
                icon: "chart.line.uptrend.xyaxis",
                color: viewModel.projectedMonthly > (viewModel.budgetLimit ?? .greatestFiniteMagnitude) ? Color.appWarning : .blue
            )
        }
    }

    private func pacingTile(title: String, value: String, subtitle: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(.primary)

                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Student Power Tools Bar

    private var studentToolsSection: some View {
        HStack(spacing: 12) {
            Button {
                showBillSplitter = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.2.slash")
                        .font(.headline)
                        .foregroundStyle(Color.appAccent)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Split Bill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.primary)
                        Text("Tip & e-Transfer")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)

            Button {
                showSemesterBudget = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "graduationcap.fill")
                        .font(.headline)
                        .foregroundStyle(Color(hex: "5856D6"))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Semester Plan")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.primary)
                        Text("Term burn rate")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
    }
}
