import SwiftUI
import PhotosUI

struct ReceiptScannerView: View {
    @Environment(\.dismiss) private var dismiss
    let onApply: (ScannedReceipt) -> Void

    @State private var scannerService = ReceiptScannerService()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var scannedReceipt: ScannedReceipt?
    @State private var isCameraPresented = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let image = selectedImage {
                        imagePreviewSection(image)
                    } else {
                        emptyPickerState
                    }

                    if scannerService.isScanning {
                        scanningIndicator
                    } else if let receipt = scannedReceipt {
                        scannedResultsCard(receipt)
                    } else if let error = scannerService.errorMessage {
                        errorCard(error)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Scan Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                if scannedReceipt?.amount != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Use Data") {
                            if let receipt = scannedReceipt {
                                onApply(receipt)
                                dismiss()
                            }
                        }
                        .fontWeight(.bold)
                        .foregroundStyle(Color.appAccent)
                    }
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        selectedImage = uiImage
                        await processImage(uiImage)
                    }
                }
            }
            .sheet(isPresented: $isCameraPresented) {
                CameraPickerView { capturedImage in
                    selectedImage = capturedImage
                    Task {
                        await processImage(capturedImage)
                    }
                }
            }
        }
    }

    // MARK: - Empty State / Image Pickers

    private var emptyPickerState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.appAccent.opacity(0.12))
                    .frame(width: 100, height: 100)

                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.appAccent)
            }
            .padding(.top, 20)

            VStack(spacing: 6) {
                Text("Scan Any Receipt")
                    .font(.title3.weight(.bold))

                Text("On-device OCR extracts merchant name, amount, and purchase date instantly")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            VStack(spacing: 12) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        isCameraPresented = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                            Text("Take Photo")
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.appAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: Color.appAccent.opacity(0.3), radius: 6, y: 2)
                    }
                }

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle")
                        Text("Choose from Photos")
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(Color.appAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.appAccent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.top, 12)
        }
    }

    // MARK: - Image Preview Section

    private func imagePreviewSection(_ image: UIImage) -> some View {
        VStack(spacing: 12) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 220)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )

            HStack(spacing: 12) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        isCameraPresented = true
                    } label: {
                        Label("Retake", systemImage: "camera")
                            .font(.caption.weight(.semibold))
                    }
                }

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("Change Photo", systemImage: "photo")
                        .font(.caption.weight(.semibold))
                }
            }
            .foregroundStyle(Color.appAccent)
        }
    }

    // MARK: - Scanning Indicator

    private var scanningIndicator: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
                .tint(Color.appAccent)

            Text("Reading receipt details with Apple Vision OCR...")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Scanned Results Card

    private func scannedResultsCard(_ receipt: ScannedReceipt) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.appAccent)
                Text("Extracted Details")
                    .font(.headline)
                Spacer()
            }

            VStack(spacing: 12) {
                scannedRow(
                    icon: "dollarsign.circle.fill",
                    label: "Total Amount",
                    value: receipt.amount != nil ? CurrencyFormatter.format(receipt.amount!) : "Not detected",
                    highlight: true
                )

                scannedRow(
                    icon: "storefront.fill",
                    label: "Merchant",
                    value: receipt.merchant ?? "Not detected",
                    highlight: false
                )

                scannedRow(
                    icon: "calendar",
                    label: "Date",
                    value: receipt.date != nil ? DateHelpers.shortDate(receipt.date!) : "Today (Default)",
                    highlight: false
                )
            }

            Button {
                onApply(receipt)
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.doc.fill")
                    Text("Auto-Fill Expense Form")
                        .fontWeight(.bold)
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.appAccent)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: Color.appAccent.opacity(0.3), radius: 6, y: 2)
            }
            .padding(.top, 4)
        }
        .padding(18)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func scannedRow(icon: String, label: String, value: String, highlight: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Color.appAccent)
                .frame(width: 24)

            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)

            Text(value)
                .font(.subheadline.weight(highlight ? .bold : .medium))
                .foregroundStyle(highlight ? Color.appAccent : .primary)

            Spacer()
        }
    }

    // MARK: - Error Card

    private func errorCard(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(Color.appWarning)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func processImage(_ image: UIImage) async {
        let result = await scannerService.scanReceipt(image: image)
        scannedReceipt = result
    }
}

// MARK: - UIKit Camera Bridge

struct CameraPickerView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView

        init(_ parent: CameraPickerView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
