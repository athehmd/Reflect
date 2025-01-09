//
//  TranscriptionView.swift
//  Reflect
//
//  Created by Jovel Ramos on 1/8/25.
//

import Speech
import AVFoundation
import SwiftUI

@MainActor
class SpeechRecognitionManager: ObservableObject {
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    
    @Published var isRecording = false
    @Published var transcribedText = ""
    @Published var errorMessage: String?
    
    init() {
        // Request speech recognition authorization
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self.errorMessage = nil
                case .denied:
                    self.errorMessage = "Speech recognition permission was denied"
                case .restricted:
                    self.errorMessage = "Speech recognition is restricted on this device"
                case .notDetermined:
                    self.errorMessage = "Speech recognition permission not determined"
                @unknown default:
                    self.errorMessage = "Unknown authorization status"
                }
            }
        }
    }
    
    func startRecording() async throws {
        // Ensure we're not already recording
        guard !isRecording else { return }
        
        // Reset any existing task
        resetRecognitionTask()
        
        // Configure the audio session
        try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement, options: .duckOthers)
        try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        
        // Create and configure the recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else {
            throw RecognitionError.unableToCreateRequest
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Configure audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        // Start the audio engine
        audioEngine.prepare()
        try audioEngine.start()
        
        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }
            
            if let result {
                self.transcribedText = result.bestTranscription.formattedString
            }
            
            if error != nil {
                self.stopRecording()
                self.errorMessage = error?.localizedDescription
            }
        }
        
        isRecording = true
    }
    
    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        isRecording = false
    }
    
    private func resetRecognitionTask() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
    }
}

// Custom errors
enum RecognitionError: Error {
    case unableToCreateRequest
    case recognitionFailed
}

// SwiftUI View
struct TranscriptionView: View {
    @StateObject private var speechManager = SpeechRecognitionManager()
    
    var body: some View {
        VStack {
            ScrollView {
                Text(speechManager.transcribedText)
                    .padding()
            }
            
            if let error = speechManager.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            }
            
            Button(speechManager.isRecording ? "Stop Recording" : "Start Recording") {
                Task {
                    if speechManager.isRecording {
                        speechManager.stopRecording()
                    } else {
                        try? await speechManager.startRecording()
                    }
                }
            }
            .padding()
        }
    }
}
