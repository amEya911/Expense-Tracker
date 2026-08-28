import SwiftUI

struct CategoryManagementView: View {
    let firestoreService: FirestoreService
    let userId: String

    @State private var categories: [ExpenseCategory] = []
    @State private var isLoading = true
    @State private var showAddCategory = false
    @State private var editingCategory: ExpenseCategory?

    // New/edit category fields
    @State private var newName = ""
    @State private var newIcon = "cup.and.saucer.fill"
    @State private var newColor = "A2845E"

    private let availableIcons = [
        "cup.and.saucer.fill", "cart.fill", "fork.knife",
        "tram.fill.tunnel", "bus.fill", "cablecar.fill",
        "tram.fill", "car.fill", "house.fill",
        "book.fill", "bag.fill", "repeat",
        "gamecontroller.fill", "bolt.fill", "heart.fill",
        "ellipsis.circle.fill", "airplane", "gift.fill",
        "graduationcap.fill", "fuelpump.fill", "dumbbell.fill",
        "film.fill", "tv.fill", "music.note",
        "pawprint.fill", "stethoscope", "cross.case.fill", "creditcard.fill"
    ]

    private let availableColors = [
        "A2845E", "34C759", "FF9500", "007AFF", "00C7BE",
        "5856D6", "30B0C7", "FF6B6B", "FF2D55", "AF52DE",
        "FFCC00", "FF3B30", "8E8E93", "30D158", "64D2FF"
    ]

    var body: some View {
        Group {
            if isLoading && categories.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if categories.filter({ !$0.isArchived }).isEmpty {
                emptyCategoriesView
            } else {
                categoriesList
            }
        }
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newName = ""
                    newIcon = "cup.and.saucer.fill"
                    newColor = "A2845E"
                    editingCategory = nil
                    showAddCategory = true
                } label: {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .task {
            await loadCategories()
        }
        .sheet(isPresented: $showAddCategory) {
            categoryEditor(isNew: true)
        }
        .sheet(item: $editingCategory) { _ in
            categoryEditor(isNew: false)
        }
    }

    private var categoriesList: some View {
        List {
            Section {
                ForEach(categories.filter { !$0.isArchived }) { category in
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(category.color.opacity(0.15))
                                .frame(width: 38, height: 38)

                            Image(systemName: category.icon)
                                .font(.body)
                                .foregroundStyle(category.color)
                        }

                        Text(category.name)
                            .font(.body.weight(.medium))

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingCategory = category
                        newName = category.name
                        newIcon = category.icon
                        newColor = category.colorHex
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task { await archiveCategory(category) }
                        } label: {
                            Label("Archive", systemImage: "archivebox")
                        }
                    }
                }
                .onMove { from, to in
                    categories.move(fromOffsets: from, toOffset: to)
                    Task { await updateSortOrders() }
                }
            } footer: {
                Text("Tap any category to edit its name, icon, or color. Swipe left to archive.")
                    .font(.caption)
            }
        }
    }

    private var emptyCategoriesView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tag.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Categories Found")
                .font(.headline)

            Text("Restore the student-focused default categories to get started.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                Task {
                    isLoading = true
                    categories = try await firestoreService.seedDefaultCategories(userId: userId)
                    isLoading = false
                }
            } label: {
                Label("Restore Default Categories", systemImage: "arrow.counterclockwise")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.appAccent)
        }
        .padding(40)
    }

    // MARK: - Category Editor

    private func categoryEditor(isNew: Bool) -> some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Category name (e.g. Coffee, Subway)", text: $newName)
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 14) {
                        ForEach(availableIcons, id: \.self) { icon in
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(newIcon == icon ? Color.appAccent.opacity(0.2) : Color(.tertiarySystemBackground))
                                    .frame(width: 44, height: 44)

                                Image(systemName: icon)
                                    .font(.title3)
                                    .foregroundStyle(newIcon == icon ? Color.appAccent : .primary)
                            }
                            .overlay {
                                if newIcon == icon {
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.appAccent, lineWidth: 2)
                                }
                            }
                            .onTapGesture {
                                newIcon = icon
                                let gen = UISelectionFeedbackGenerator()
                                gen.selectionChanged()
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 14) {
                        ForEach(availableColors, id: \.self) { color in
                            Circle()
                                .fill(Color(hex: color))
                                .frame(width: 36, height: 36)
                                .overlay {
                                    if newColor == color {
                                        Circle()
                                            .stroke(.white, lineWidth: 3)
                                            .frame(width: 28, height: 28)
                                    }
                                }
                                .onTapGesture {
                                    newColor = color
                                    let gen = UISelectionFeedbackGenerator()
                                    gen.selectionChanged()
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Preview
                Section("Preview") {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(hex: newColor).opacity(0.15))
                                .frame(width: 48, height: 48)

                            Image(systemName: newIcon)
                                .font(.title3)
                                .foregroundStyle(Color(hex: newColor))
                        }

                        Text(newName.isEmpty ? "Category Name" : newName)
                            .font(.headline)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(isNew ? "New Category" : "Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showAddCategory = false
                        editingCategory = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if isNew {
                                await addCategory()
                            } else {
                                await updateCategory()
                            }
                            showAddCategory = false
                            editingCategory = nil
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    // MARK: - Actions

    private func loadCategories() async {
        isLoading = true
        do {
            categories = try await firestoreService.getCategories(userId: userId)
        } catch {
            print("Failed to load categories: \(error)")
        }
        isLoading = false
    }

    private func addCategory() async {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let category = ExpenseCategory(
            userId: userId,
            name: trimmed,
            icon: newIcon,
            colorHex: newColor,
            sortOrder: categories.count
        )
        do {
            _ = try await firestoreService.addCategory(category)
            await loadCategories()
        } catch {
            print("Failed to add category: \(error)")
        }
    }

    private func updateCategory() async {
        guard var cat = editingCategory else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        cat.name = trimmed
        cat.icon = newIcon
        cat.colorHex = newColor
        do {
            try await firestoreService.updateCategory(cat)
            await loadCategories()
        } catch {
            print("Failed to update category: \(error)")
        }
    }

    private func archiveCategory(_ category: ExpenseCategory) async {
        var cat = category
        cat.isArchived = true
        do {
            try await firestoreService.updateCategory(cat)
            await loadCategories()
        } catch {
            print("Failed to archive category: \(error)")
        }
    }

    private func updateSortOrders() async {
        for (index, var category) in categories.enumerated() {
            category.sortOrder = index
            do {
                try await firestoreService.updateCategory(category)
            } catch {
                print("Failed to update sort order: \(error)")
            }
        }
    }
}
