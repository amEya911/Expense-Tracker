import SwiftUI
import Charts

struct AllTimeSummarySheet: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: AnalyticsViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - Hero Summary Card
                    heroSummaryCard

                    // MARK: - Top Category & Merchant Highlight
                    topHighlightsSection

                    // MARK: - Payment Methods Horizontal Bar Graph
                    if !viewModel.allTimePaymentBreakdown.isEmpty {
                        paymentMethodsCard
                    }

                    // MARK: - Category Breakdown (Donut Chart)
                    if !viewModel.allTimeCategoryBreakdown.isEmpty {
                        categoryBreakdownCard
                    }

                    // MARK: - Monthly Spending History
                    if viewModel.allTimeMonthlyTrends.count > 1 {
                        monthlyTrendsCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("All-Time Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appAccent)
                }
            }
        }
    }

    // MARK: - Hero Summary Card

    private var heroSummaryCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("LIFETIME SPENDING")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .tracking(1)

                    Text(CurrencyFormatter.format(viewModel.allTimeTotalSpent))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                Spacer()

                Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.appAccent.gradient)
            }

            Divider()

            HStack(spacing: 16) {
                statItem(
                    label: "Transactions",
                    value: "\(viewModel.allTimeTransactionCount)",
                    icon: "list.bullet.rectangle.portrait.fill",
                    color: .blue
                )

                Divider()

                statItem(
                    label: "Avg Expense",
                    value: CurrencyFormatter.format(viewModel.allTimeAverageTransaction),
                    icon: "divide.circle.fill",
                    color: .teal
                )

                Divider()

                statItem(
                    label: "Tracked Months",
                    value: "\(max(viewModel.allTimeMonthlyTrends.count, 1))",
                    icon: "calendar.badge.clock",
                    color: .purple
                )
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }

    private func statItem(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Top Highlights

    private var topHighlightsSection: some View {
        HStack(spacing: 12) {
            if let topCat = viewModel.allTimeTopCategory {
                VStack(alignment: .leading, spacing: 6) {
                    Text("TOP CATEGORY")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)

                    Text(topCat.name)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(CurrencyFormatter.format(topCat.amount))
                        .font(.caption)
                        .foregroundStyle(Color.appAccent)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            if let topMerchant = viewModel.allTimeTopMerchant {
                VStack(alignment: .leading, spacing: 6) {
                    Text("TOP MERCHANT")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)

                    Text(topMerchant.name)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(CurrencyFormatter.format(topMerchant.amount))
                        .font(.caption)
                        .foregroundStyle(Color.appAccent)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    // MARK: - Payment Methods Horizontal Bar Graph

    private var paymentMethodsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PAYMENT METHODS")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .tracking(1)
                    Text("Total Outflow by Method")
                        .font(.subheadline.weight(.semibold))
                }
                Spacer()
                Image(systemName: "creditcard.and.123")
                    .foregroundStyle(.secondary)
            }

            // Horizontal Bar Chart
            Chart(viewModel.allTimePaymentBreakdown) { method in
                BarMark(
                    x: .value("Amount", NSDecimalNumber(decimal: method.amount).doubleValue),
                    y: .value("Method", method.name)
                )
                .foregroundStyle(method.color.gradient)
                .cornerRadius(6)
                .annotation(position: .trailing, alignment: .leading) {
                    Text(CurrencyFormatter.format(method.amount))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.caption.weight(.medium))
                }
            }
            .chartXAxis(.hidden)
            .frame(height: CGFloat(max(viewModel.allTimePaymentBreakdown.count * 42, 140)))

            Divider()

            // List Breakdown
            VStack(spacing: 10) {
                ForEach(viewModel.allTimePaymentBreakdown) { method in
                    HStack(spacing: 10) {
                        Image(systemName: method.icon)
                            .font(.subheadline)
                            .foregroundStyle(method.color)
                            .frame(width: 24)

                        Text(method.name)
                            .font(.subheadline.weight(.medium))

                        Text("(\(method.count))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(CurrencyFormatter.format(method.amount))
                                .font(.subheadline.weight(.semibold))
                            Text("\(String(format: "%.1f", method.percentage))%")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Category Donut Chart

    private var categoryBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("CATEGORY BREAKDOWN")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(1)

            // Donut Chart
            Chart(viewModel.allTimeCategoryBreakdown) { slice in
                SectorMark(
                    angle: .value("Amount", NSDecimalNumber(decimal: slice.amount).doubleValue),
                    innerRadius: .ratio(0.6),
                    angularInset: 2
                )
                .foregroundStyle(slice.color)
                .cornerRadius(4)
            }
            .frame(height: 200)

            Divider()

            // Slices List
            VStack(spacing: 10) {
                ForEach(viewModel.allTimeCategoryBreakdown) { slice in
                    HStack(spacing: 10) {
                        Image(systemName: slice.icon)
                            .font(.subheadline)
                            .foregroundStyle(slice.color)
                            .frame(width: 24)

                        Text(slice.name)
                            .font(.subheadline.weight(.medium))

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(CurrencyFormatter.format(slice.amount))
                                .font(.subheadline.weight(.semibold))
                            Text("\(String(format: "%.1f", slice.percentage))%")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Monthly Trends

    private var monthlyTrendsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("MONTHLY SPENDING HISTORY")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(1)

            Chart(viewModel.allTimeMonthlyTrends) { point in
                BarMark(
                    x: .value("Month", point.monthLabel),
                    y: .value("Spent", point.amount)
                )
                .foregroundStyle(Color.appAccent.gradient)
                .cornerRadius(6)
            }
            .frame(height: 180)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let d = value.as(Double.self) {
                            Text("$\(Int(d))")
                                .font(.caption2)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
