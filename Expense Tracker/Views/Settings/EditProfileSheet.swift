import SwiftUI
import PhotosUI

struct EditProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: SettingsViewModel

    @State private var displayName: String = ""
    @State private var selectedIcon: String = "person.crop.circle.fill"
    @State private var selectedColorHex: String = "00C48C"
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var existingAvatarUrl: String?
    @State private var hasRemovedCustomPhoto = false
    @State private var isSaving = false

    private let presetIcons = [
        "person.crop.circle.fill",
        "graduationcap.fill",
        "sparkles",
        "laptopcomputer",
        "cup.and.saucer.fill",
        "tram.fill",
        "cart.fill",
        "book.closed.fill",
        "airplane",
        "bolt.fill",
        "heart.fill",
        "star.fill"
    ]

    private let presetColors = [
        "00C48C", // Emerald
        "4F46E5", // Indigo
        "9333EA", // Purple
        "0284C7", // Sky Blue
        "0D9488", // Teal
        "EA580C", // Orange
        "E11D48", // Rose
        "D97706"  // Amber
    ]

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Avatar Preview & Picker
                Section {
                    VStack(spacing: 16) {
                        avatarPreview
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 8)

                        PhotosPicker(
                            selection: $selectedPhotoItem,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            Label(hasActiveCustomPhoto ? "Change Custom Photo" : "Upload Custom Photo", systemImage: "photo.badge.plus")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.appAccent)
                        }

                        if hasActiveCustomPhoto {
                            Button("Use Preset Avatar Instead", role: .destructive) {
                                selectedImageData = nil
                                selectedPhotoItem = nil
                                hasRemovedCustomPhoto = true
                            }
                            .font(.caption)
                        }
                    }
                    .listRowBackground(Color.clear)
                }

                // MARK: - Preset Icons & Colors (shown when using preset avatar)
                if !hasActiveCustomPhoto {
                    Section("Choose Avatar Icon") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                            ForEach(presetIcons, id: \.self) { icon in
                                let isSelected = selectedIcon == icon
                                Button {
                                    selectedIcon = icon
                                    let gen = UIImpactFeedbackGenerator(style: .light)
                                    gen.impactOccurred()
                                } label: {
                                    Image(systemName: icon)
                                        .font(.title3)
                                        .frame(width: 44, height: 44)
                                        .background(isSelected ? Color(hex: selectedColorHex).opacity(0.2) : Color(.secondarySystemBackground))
                                        .foregroundStyle(isSelected ? Color(hex: selectedColorHex) : .secondary)
                                        .clipShape(Circle())
                                        .overlay {
                                            if isSelected {
                                                Circle()
                                                    .stroke(Color(hex: selectedColorHex), lineWidth: 2)
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    Section("Choose Avatar Color") {
                        HStack(spacing: 12) {
                            ForEach(presetColors, id: \.self) { hex in
                                let isSelected = selectedColorHex == hex
                                Button {
                                    selectedColorHex = hex
                                    let gen = UIImpactFeedbackGenerator(style: .light)
                                    gen.impactOccurred()
                                } label: {
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 34, height: 34)
                                        .overlay {
                                            if isSelected {
                                                Image(systemName: "checkmark")
                                                    .font(.caption.bold())
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }

                // MARK: - Personal Information
                Section("Personal Details") {
                    HStack {
                        Text("Display Name")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(width: 100, alignment: .leading)
                        TextField("Your Name", text: $displayName)
                            .autocorrectionDisabled()
                    }

                    HStack {
                        Text("Email")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(width: 100, alignment: .leading)
                        Text(viewModel.email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Task { await saveProfile() }
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.appAccent)
                    .disabled(isSaving || displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                displayName = viewModel.displayName
                selectedIcon = viewModel.avatarIcon
                selectedColorHex = viewModel.avatarColorHex
                existingAvatarUrl = viewModel.avatarUrl
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        if let uiImage = UIImage(data: data) {
                            let resized = uiImage.preparingThumbnail(of: CGSize(width: 400, height: 400)) ?? uiImage
                            selectedImageData = resized.jpegData(compressionQuality: 0.75)
                            hasRemovedCustomPhoto = false
                        }
                    }
                }
            }
        }
    }

    private var hasActiveCustomPhoto: Bool {
        if selectedImageData != nil { return true }
        if let url = existingAvatarUrl, !url.isEmpty, !hasRemovedCustomPhoto { return true }
        return false
    }

    @ViewBuilder
    private var avatarPreview: some View {
        if let data = selectedImageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 88, height: 88)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
        } else if let urlStr = existingAvatarUrl, let url = URL(string: urlStr), !hasRemovedCustomPhoto {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: 88, height: 88)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 88, height: 88)
                        .clipShape(Circle())
                case .failure:
                    presetAvatarView
                @unknown default:
                    presetAvatarView
                }
            }
            .frame(width: 88, height: 88)
            .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
        } else {
            presetAvatarView
        }
    }

    private var presetAvatarView: some View {
        Circle()
            .fill(Color(hex: selectedColorHex).opacity(0.18))
            .frame(width: 88, height: 88)
            .overlay {
                Image(systemName: selectedIcon)
                    .font(.system(size: 40))
                    .foregroundStyle(Color(hex: selectedColorHex))
            }
            .shadow(color: Color(hex: selectedColorHex).opacity(0.2), radius: 6, y: 3)
    }

    private func saveProfile() async {
        isSaving = true
        let success = await viewModel.updateProfile(
            displayName: displayName,
            avatarIcon: selectedIcon,
            avatarColorHex: selectedColorHex,
            newImageData: selectedImageData,
            shouldRemoveCustomPhoto: hasRemovedCustomPhoto
        )
        isSaving = false
        if success {
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(.success)
            dismiss()
        }
    }
}
