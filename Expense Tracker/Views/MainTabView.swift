import SwiftUI

struct MainTabView: View {
    let authService: AuthService
    let firestoreService: FirestoreService
    let userId: String

    @State private var selectedTab = 0
    @State private var showAddExpense = false

    @State private var dashboardViewModel: DashboardViewModel
    @State private var transactionViewModel: TransactionViewModel
    @State private var budgetViewModel: BudgetViewModel
    @State private var settingsViewModel: SettingsViewModel

    init(authService: AuthService, firestoreService: FirestoreService, userId: String) {
        self.authService = authService
        self.firestoreService = firestoreService
        self.userId = userId

        _dashboardViewModel = State(initialValue: DashboardViewModel(firestoreService: firestoreService, userId: userId))
        _transactionViewModel = State(initialValue: TransactionViewModel(firestoreService: firestoreService, userId: userId))
        _budgetViewModel = State(initialValue: BudgetViewModel(firestoreService: firestoreService, userId: userId))
        _settingsViewModel = State(initialValue: SettingsViewModel(authService: authService, firestoreService: firestoreService))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house", value: 0) {
                DashboardView(
                    viewModel: dashboardViewModel,
                    onAddExpense: { showAddExpense = true }
                )
            }

            Tab("Transactions", systemImage: "list.bullet", value: 1) {
                TransactionListView(
                    viewModel: transactionViewModel,
                    firestoreService: firestoreService,
                    userId: userId
                )
            }

            // Center add button: triggers expense modal sheet
            Tab("Add", systemImage: "plus.circle.fill", value: 2) {
                Color.clear
                    .onAppear {
                        showAddExpense = true
                        selectedTab = 0
                    }
            }

            Tab("Analytics", systemImage: "chart.pie.fill", value: 3) {
                BudgetOverviewView(
                    viewModel: budgetViewModel
                )
            }

            Tab("Settings", systemImage: "gearshape", value: 4) {
                SettingsView(
                    viewModel: settingsViewModel,
                    firestoreService: firestoreService,
                    userId: userId
                )
            }
        }
        .tint(.appAccent)
        .sheet(isPresented: $showAddExpense) {
            AddExpenseView(
                viewModel: ExpenseViewModel(firestoreService: firestoreService, userId: userId)
            )
        }
        .onChange(of: showAddExpense) { _, isPresented in
            if !isPresented {
                // Refresh dashboard and transactions whenever an expense is added/dismissed
                Task {
                    async let d = dashboardViewModel.loadData()
                    async let t = transactionViewModel.loadData()
                    async let b = budgetViewModel.loadData()
                    _ = await (d, t, b)
                }
            }
        }
    }
}
