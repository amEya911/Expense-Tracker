import Foundation
import Speech
import AVFoundation

@Observable
final class SpeechRecognitionService {
    var transcript: String = ""
    var isListening: Bool = false
    var error: String?
    var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-CA"))
    }

    // MARK: - Permission

    func requestAuthorization() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    self.authorizationStatus = status
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorized
    }

    // MARK: - Start Listening

    func startListening() {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            error = "Speech recognition is not available on this device."
            return
        }

        // Reset state
        stopListening()
        transcript = ""
        error = nil

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            self.error = "Could not configure audio session: \(error.localizedDescription)"
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else {
            self.error = "Unable to create speech recognition request."
            return
        }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.addsPunctuation = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Remove any existing taps
        inputNode.removeTap(onBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }

            if let result {
                DispatchQueue.main.async {
                    self.transcript = result.bestTranscription.formattedString
                }

                if result.isFinal {
                    DispatchQueue.main.async {
                        self.stopListening()
                    }
                }
            }

            if let error {
                DispatchQueue.main.async {
                    // Ignore cancellation errors (they happen when we manually stop)
                    let nsError = error as NSError
                    if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216 {
                        // User cancelled, not an error
                        return
                    }
                    if nsError.code == 1110 {
                        // "No speech detected" - not a critical error
                        if self.transcript.isEmpty {
                            self.error = "No speech detected. Please try again."
                        }
                        self.stopListening()
                        return
                    }
                    self.error = "Recognition error: \(error.localizedDescription)"
                    self.stopListening()
                }
            }
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
        } catch {
            self.error = "Could not start audio engine: \(error.localizedDescription)"
            stopListening()
        }
    }

    // MARK: - Stop Listening

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false

        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
