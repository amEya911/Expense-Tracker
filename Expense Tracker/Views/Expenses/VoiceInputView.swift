import SwiftUI

struct VoiceInputView: View {
    @Environment(\.dismiss) private var dismiss

    let categories: [ExpenseCategory]
    let onConfirm: (ParsedExpense) -> Void

    @State private var speechService = SpeechRecognitionService()
    @State private var parsedExpense: ParsedExpense?
    @State private var viewState: ViewState = .idle
    @State private var pulseScale: CGFloat = 1.0
    @AppStorage("hasSeenVoiceTutorial") private var hasSeenTutorial = false
    @State private var showTutorial = false

    enum ViewState {
        case idle
        case listening
        case processing
        case result
        case error
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 28) {
                    Spacer()

                    // State-specific content
                    switch viewState {
                    case .idle:
                        idleView
                    case .listening:
                        listeningView
                    case .processing:
                        processingView
                    case .result:
                        resultView
                    case .error:
                        errorView
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)

                // First-time tutorial overlay
                if showTutorial {
                    tutorialOverlay
                }
            }
            .navigationTitle("Voice Input")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }

                if viewState == .listening || viewState == .result {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showTutorial = true
                        } label: {
                            Image(systemName: "questionmark.circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onAppear {
                if !hasSeenTutorial {
                    showTutorial = true
                }
            }
        }
    }

    // MARK: - Idle View

    private var idleView: some View {
        VStack(spacing: 24) {
            Image(systemName: "mic.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.appAccent)

            VStack(spacing: 8) {
                Text("Tap the mic to start")
                    .font(.title3.weight(.semibold))
                Text("Describe your expense naturally")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            micButton {
                Task { await startRecording() }
            }
        }
    }

    // MARK: - Listening View

    private var listeningView: some View {
        VStack(spacing: 24) {
            // Pulsing mic with ring
            ZStack {
                Circle()
                    .fill(Color.appAccent.opacity(0.12))
                    .frame(width: 120, height: 120)
                    .scaleEffect(pulseScale)
                    .animation(
                        .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                        value: pulseScale
                    )

                Circle()
                    .fill(Color.appAccent.opacity(0.06))
                    .frame(width: 160, height: 160)
                    .scaleEffect(pulseScale * 0.9)
                    .animation(
                        .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                        value: pulseScale
                    )

                Button {
                    stopAndProcess()
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.white)
                        .frame(width: 80, height: 80)
                        .background(Color.appAccent)
                        .clipShape(Circle())
                        .shadow(color: Color.appAccent.opacity(0.4), radius: 12, y: 4)
                }
            }
            .onAppear { pulseScale = 1.2 }

            Text("Listening...")
                .font(.headline)
                .foregroundStyle(Color.appAccent)

            // Live transcript
            if !speechService.transcript.isEmpty {
                Text(speechService.transcript)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .transition(.opacity)
            }

            Text("Tap the mic to stop")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Processing View

    private var processingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .controlSize(.large)
                .tint(Color.appAccent)

            Text("Processing your expense...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Result View

    private var resultView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.appAccent)

            Text("Here is what I understood:")
                .font(.headline)

            // Parsed fields display
            if let parsed = parsedExpense {
                VStack(spacing: 12) {
                    parsedField(
                        icon: "dollarsign.circle.fill",
                        label: "Amount",
                        value: parsed.amount != nil ? CurrencyFormatter.format(parsed.amount!) : "Not detected",
                        detected: parsed.amount != nil
                    )
                    parsedField(
                        icon: "square.grid.2x2.fill",
                        label: "Category",
                        value: parsed.categoryName ?? "Not detected",
                        detected: parsed.categoryName != nil
                    )
                    parsedField(
                        icon: "storefront.fill",
                        label: "Merchant",
                        value: parsed.merchant ?? "Not detected",
                        detected: parsed.merchant != nil
                    )
                    parsedField(
                        icon: "calendar",
                        label: "Date",
                        value: parsed.date != nil ? DateHelpers.shortDate(parsed.date!) : "Not detected",
                        detected: parsed.date != nil
                    )
                    parsedField(
                        icon: "creditcard.fill",
                        label: "Payment",
                        value: parsed.paymentMethod ?? "Not detected",
                        detected: parsed.paymentMethod != nil
                    )
                }
                .padding(16)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            // Transcript preview
            if !speechService.transcript.isEmpty {
                Text("\"\(speechService.transcript)\"")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .italic()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    viewState = .idle
                    speechService.transcript = ""
                    parsedExpense = nil
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Try Again")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.appAccent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    if let parsed = parsedExpense {
                        onConfirm(parsed)
                        dismiss()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                        Text("Use This")
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.appAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: Color.appAccent.opacity(0.3), radius: 6, y: 2)
                }
            }
        }
    }

    // MARK: - Error View

    private var errorView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.appWarning)

            Text("Could not understand")
                .font(.title3.weight(.semibold))

            Text(speechService.error ?? "Your voice could not be understood. Please try again or enter the expense manually.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button {
                    viewState = .idle
                    speechService.transcript = ""
                    speechService.error = nil
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "mic.fill")
                        Text("Try Again")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.appAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    dismiss()
                } label: {
                    Text("Enter Manually")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    // MARK: - Tutorial Overlay

    private var tutorialOverlay: some View {
        ZStack {
            Color.black.opacity(0.65)
                .ignoresSafeArea()
                .onTapGesture { /* block taps */ }

            VStack(spacing: 24) {
                Image(systemName: "waveform.and.mic")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.appAccent)

                Text("Voice Expense Entry")
                    .font(.title2.weight(.bold))

                Text("Describe your expense naturally in one sentence. Include the amount, what you bought, where, when, and how you paid.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 12) {
                    exampleBubble("Six thirty-five on groceries at Walmart, today by credit card")
                    exampleBubble("I spent seventy-four dollars on dining at Popeyes yesterday using debit card")
                    exampleBubble("Twelve dollars on coffee at Starbucks today, paid cash")
                }

                Button {
                    hasSeenTutorial = true
                    withAnimation(.spring(response: 0.3)) {
                        showTutorial = false
                    }
                } label: {
                    Text("Got It")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.appAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(28)
            .background(.ultraThickMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 24)
            .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
            .transition(.scale.combined(with: .opacity))
        }
    }

    // MARK: - Helpers

    private func micButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "mic.fill")
                .font(.system(size: 32))
                .foregroundStyle(.white)
                .frame(width: 80, height: 80)
                .background(Color.appAccent)
                .clipShape(Circle())
                .shadow(color: Color.appAccent.opacity(0.4), radius: 12, y: 4)
        }
    }

    private func parsedField(icon: String, label: String, value: String, detected: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(detected ? Color.appAccent : Color.gray.opacity(0.4))
                .frame(width: 28)

            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)

            Text(value)
                .font(.subheadline.weight(detected ? .semibold : .regular))
                .foregroundStyle(detected ? .primary : .tertiary)

            Spacer()

            if detected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(Color.appAccent)
            } else {
                Image(systemName: "xmark.circle")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func exampleBubble(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "text.quote")
                .font(.caption)
                .foregroundStyle(Color.appAccent)
            Text(text)
                .font(.caption)
                .foregroundStyle(.primary)
                .italic()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appAccent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Recording Logic

    private func startRecording() async {
        let authorized = await speechService.requestAuthorization()
        guard authorized else {
            speechService.error = "Speech recognition permission was denied. Please enable it in Settings > Privacy > Speech Recognition."
            viewState = .error
            return
        }

        speechService.startListening()
        withAnimation(.spring(response: 0.4)) {
            viewState = .listening
        }
    }

    private func stopAndProcess() {
        speechService.stopListening()

        withAnimation(.spring(response: 0.3)) {
            viewState = .processing
        }

        // Small delay for UX feel
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let transcript = speechService.transcript

            if transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                speechService.error = "No speech was detected. Please try again and speak clearly."
                withAnimation { viewState = .error }
                return
            }

            let parsed = VoiceExpenseParser.parse(transcript)
            parsedExpense = parsed

            // Check if at least amount was detected
            if parsed.amount == nil && parsed.categoryName == nil && parsed.merchant == nil {
                speechService.error = "Could not understand the expense details. Try saying something like: \"twelve dollars on coffee at Starbucks today by credit card\""
                withAnimation { viewState = .error }
                return
            }

            withAnimation(.spring(response: 0.4)) {
                viewState = .result
            }
        }
    }
}
