import SwiftUI

struct TransactionListView: View {
    @Bindable var viewModel: TransactionViewModel
    let firestoreService: FirestoreService
    let userId: String

    @State private var editingExpense: Expense?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    TransactionSkeletonView()
                } else if viewModel.filteredExpenses.isEmpty {
                    emptyState
                } else {
                    transactionList
                }
            }
            .navigationTitle("Transactions")
            .searchable(text: $viewModel.searchText, prompt: "Search by merchant, category, or notes")
            .toolbar {
                if !viewModel.expenses.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(
                            item: CSVExportService.generateCSV(expenses: viewModel.expenses, categories: viewModel.categories),
                            subject: Text("Expense Tracker Export"),
                            message: Text("Here is my exported expense data from Expense Tracker.")
                        ) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.body)
                                .foregroundStyle(Color.appAccent)
                        }
                    }
                }
            }
            .refreshable {
                await viewModel.loadData()
            }
            .task {
                await viewModel.loadData()
            }
            .sheet(item: $editingExpense) { expense in
                let vm = ExpenseViewModel(firestoreService: firestoreService, userId: userId)
                AddExpenseView(viewModel: vm)
                    .onAppear {
                        vm.loadForEditing(expense)
                        Task { await vm.loadData() }
                    }
            }
        }
    }

    // MARK: - Transaction List

    private var transactionList: some View {
        List {
            ForEach(viewModel.groupedExpenses, id: \.label) { group in
                Section {
                    ForEach(group.expenses) { expense in
                        TransactionRowView(
                            expense: expense,
                            category: viewModel.category(for: expense.categoryId)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingExpense = expense
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task { await viewModel.deleteExpense(expense) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text(group.label)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)
            Text("No transactions yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Tap the + button to add your first expense.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}

// MARK: - Transaction Row

struct TransactionRowView: View {
    let expense: Expense
    let category: ExpenseCategory?

    var body: some View {
        HStack(spacing: 14) {
            // Category icon
            Image(systemName: category?.icon ?? "circle")
                .font(.body)
                .foregroundStyle(category?.color ?? .secondary)
                .frame(width: 40, height: 40)
                .background((category?.color ?? .secondary).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            // Details
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(expense.merchant.isEmpty ? (category?.name ?? "Expense") : expense.merchant)
                        .font(.subheadline.weight(.medium))

                    if expense.isPrestoPayment {
                        Text("PRESTO")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: "00C48C").opacity(0.18))
                            .foregroundStyle(Color(hex: "00C48C"))
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 4) {
                    if let cat = category {
                        Text(cat.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !expense.notes.isEmpty {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.quaternary)
                        Text(expense.notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // Amount
            VStack(alignment: .trailing, spacing: 2) {
                Text(CurrencyFormatter.format(expense.decimalAmount))
                    .font(.subheadline.weight(.semibold).monospacedDigit())

                if expense.isPrestoPayment {
                    Text("Presto Card")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(expense.merchant.isEmpty ? (category?.name ?? "Expense") : expense.merchant), \(CurrencyFormatter.format(expense.decimalAmount))")
    }
}
