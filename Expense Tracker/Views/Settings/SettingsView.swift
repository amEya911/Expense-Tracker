import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    let firestoreService: FirestoreService
    let userId: String

    @AppStorage("appTheme") private var appTheme: String = "system"
    @AppStorage("biometricsEnabled") private var biometricsEnabled: Bool = false

    @State private var showEditProfile = false
    @State private var showEditBudget = false
    @State private var showSemesterBudget = false
    @State private var budgetViewModel: BudgetViewModel?

    @State private var exportedCSVURL: URL?
    @State private var isExportingCSV = false

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

                // MARK: - Security Section
                Section("Security") {
                    Toggle(isOn: $biometricsEnabled) {
                        HStack(spacing: 12) {
                            Image(systemName: BiometricAuthManager.shared.biometryIcon)
                                .foregroundStyle(Color.appAccent)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Require \(BiometricAuthManager.shared.biometryName)")
                                    .font(.body)
                                Text("Lock app when leaving or switching apps")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .tint(Color.appAccent)
                    .onChange(of: biometricsEnabled) { _, isEnabled in
                        if isEnabled {
                            Task {
                                let success = await BiometricAuthManager.shared.authenticate(reason: "Enable \(BiometricAuthManager.shared.biometryName) protection")
                                if !success {
                                    biometricsEnabled = false
                                }
                            }
                        } else {
                            BiometricAuthManager.shared.unlockDirectly()
                        }
                    }
                }

                // MARK: - Student Budget & Management Section
                Section("Manage & Student Tools") {
                    Button {
                        showSemesterBudget = true
                    } label: {
                        HStack {
                            Label("Academic Semester Budget", systemImage: "graduationcap.fill")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
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

                    NavigationLink {
                        CategoryManagementView(
                            firestoreService: firestoreService,
                            userId: userId
                        )
                    } label: {
                        Label("Categories", systemImage: "tag.fill")
                    }
                }

                // MARK: - Data & Export Section
                Section("Data & Export") {
                    if let url = exportedCSVURL {
                        ShareLink(item: url) {
                            HStack {
                                Label("Share / Save CSV Export", systemImage: "square.and.arrow.up")
                                    .foregroundStyle(Color.appAccent)
                                Spacer()
                            }
                        }
                    } else {
                        Button {
                            Task { await exportTransactionsCSV() }
                        } label: {
                            HStack {
                                Label(isExportingCSV ? "Preparing CSV..." : "Export Expenses (CSV)", systemImage: "arrow.down.doc.fill")
                                    .foregroundStyle(.primary)
                                Spacer()
                                if isExportingCSV {
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(isExportingCSV)
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
            .sheet(isPresented: $showSemesterBudget) {
                SemesterBudgetSheet()
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
                    Task {
                        await viewModel.deleteAccount()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you absolutely sure? All your expenses, budgets, and categories will be permanently deleted.")
            }
        }
    }

    private func exportTransactionsCSV() async {
        isExportingCSV = true
        do {
            async let exps = firestoreService.getExpenses(userId: userId)
            async let cats = firestoreService.getCategories(userId: userId)
            let (loadedExpenses, loadedCategories) = try await (exps, cats)

            if let url = CSVExportService.generateCSVFileURL(expenses: loadedExpenses, categories: loadedCategories) {
                exportedCSVURL = url
                let gen = UINotificationFeedbackGenerator()
                gen.notificationOccurred(.success)
            }
        } catch {
            print("Export error: \(error.localizedDescription)")
        }
        isExportingCSV = false
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
