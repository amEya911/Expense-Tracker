import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    let firestoreService: FirestoreService
    let userId: String

    @AppStorage("appTheme") private var appTheme: String = "system"
    @State private var showEditProfile = false
    @State private var showEditBudget = false
    @State private var budgetViewModel: BudgetViewModel?

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Profile Section
                Section {
                    HStack(spacing: 16) {
                        profileAvatarView
                            .frame(width: 58, height: 58)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.displayName)
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Text(viewModel.email)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Button {
                            showEditProfile = true
                        } label: {
                            Text("Edit")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.appAccent)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.appAccent.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }

                // MARK: - Appearance Section
                Section("Appearance") {
                    Picker("Theme", selection: $appTheme) {
                        Label("System", systemImage: "circle.righthalf.filled").tag("system")
                        Label("Light", systemImage: "sun.max.fill").tag("light")
                        Label("Dark", systemImage: "moon.fill").tag("dark")
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 4)
                }

                // MARK: - Management Section
                Section("Manage") {
                    NavigationLink {
                        CategoryManagementView(
                            firestoreService: firestoreService,
                            userId: userId
                        )
                    } label: {
                        Label("Categories", systemImage: "tag.fill")
                    }

                    Button {
                        if budgetViewModel == nil {
                            budgetViewModel = BudgetViewModel(firestoreService: firestoreService, userId: userId)
                        }
                        showEditBudget = true
                    } label: {
                        HStack {
                            Label("Monthly Budget Limits", systemImage: "chart.pie.fill")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // MARK: - App Information
                Section("About") {
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }

                // MARK: - Account Actions
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
            .sheet(isPresented: $showEditProfile, onDismiss: {
                Task { await viewModel.loadProfile() }
            }) {
                EditProfileSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showEditBudget) {
                if let bVM = budgetViewModel {
                    EditBudgetSheet(viewModel: bVM)
                }
            }
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

    @ViewBuilder
    private var profileAvatarView: some View {
        if let urlStr = viewModel.avatarUrl, let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: 58, height: 58)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 58, height: 58)
                        .clipShape(Circle())
                case .failure:
                    presetAvatarView
                @unknown default:
                    presetAvatarView
                }
            }
            .frame(width: 58, height: 58)
            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
        } else {
            presetAvatarView
        }
    }

    private var presetAvatarView: some View {
        Circle()
            .fill(viewModel.avatarColor.opacity(0.18))
            .frame(width: 58, height: 58)
            .overlay {
                Image(systemName: viewModel.avatarIcon)
                    .font(.system(size: 28))
                    .foregroundStyle(viewModel.avatarColor)
            }
            .shadow(color: viewModel.avatarColor.opacity(0.2), radius: 4, y: 2)
    }
}
