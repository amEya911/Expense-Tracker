import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    let firestoreService: FirestoreService
    let userId: String

    @State private var showCategoryManagement = false

    var body: some View {
        NavigationStack {
            List {
                // Profile section
                Section {
                    HStack(spacing: 14) {
                        Circle()
                            .fill(Color.appAccent.opacity(0.2))
                            .frame(width: 48, height: 48)
                            .overlay {
                                Text(String(viewModel.displayName.prefix(1)).uppercased())
                                    .font(.title3.bold())
                                    .foregroundStyle(.appAccent)
                            }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewModel.displayName)
                                .font(.headline)
                            Text(viewModel.email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Management
                Section("Manage") {
                    NavigationLink {
                        CategoryManagementView(
                            firestoreService: firestoreService,
                            userId: userId
                        )
                    } label: {
                        Label("Categories", systemImage: "tag")
                    }

                    NavigationLink {
                        BudgetOverviewView(
                            viewModel: BudgetViewModel(firestoreService: firestoreService, userId: userId)
                        )
                    } label: {
                        Label("Budgets", systemImage: "chart.pie")
                    }
                }

                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }

                // Account actions
                Section {
                    Button {
                        viewModel.showSignOutConfirmation = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(.primary)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        viewModel.showDeleteConfirmation = true
                    } label: {
                        Label("Delete Account", systemImage: "trash")
                    }
                } footer: {
                    Text("This will permanently delete your account and all financial data. This action cannot be undone.")
                }
            }
            .navigationTitle("Settings")
            .task {
                await viewModel.loadProfile()
            }
            .confirmationDialog(
                "Sign Out",
                isPresented: $viewModel.showSignOutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    viewModel.signOut()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .confirmationDialog(
                "Delete Account",
                isPresented: $viewModel.showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Everything", role: .destructive) {
                    Task { await viewModel.deleteAccount() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete your account and all your financial data. This cannot be undone.")
            }
            .alert("Error", isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}
