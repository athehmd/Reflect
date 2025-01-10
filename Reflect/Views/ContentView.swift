import SwiftUI
import AVFoundation
import Speech

// MARK: - Models
struct SavedRecording: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let date: Date
    let duration: TimeInterval
    let transcript: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: SavedRecording, rhs: SavedRecording) -> Bool {
        lhs.id == rhs.id
    }
}

struct TranscriptionSegment: Identifiable {
    let id = UUID()
    let text: String
    let start: Float
    let end: Float
}

// MARK: - Recording View
@MainActor
struct RecordingView: View {
    @StateObject private var speechManager = SpeechRecognitionManager()
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var bufferEnergy: [Float] = []
    @State private var isRecording = false
    @State private var isPaused = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Waveform and Timer
            VStack {
                audioWaveform
                    .padding()
                
                Text(formatDuration(elapsedTime))
                    .font(.system(size: 54, weight: .semibold, design: .monospaced))
                    .foregroundColor(.primary)
            }
            .padding(.top, 30)
            
            // Recording Controls
            recordingControls
            
            // Transcription Area
            ScrollView {
                Text(speechManager.transcribedText)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            .padding()
        }
        .navigationTitle("Record")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Recording Controls
    private var recordingControls: some View {
        HStack(spacing: 40) {
            if !isRecording {
                // Initial state - just the record button
                Button(action: startRecording) {
                    VStack {
                        Image(systemName: "record.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.red)
                        Text("Record")
                            .font(.caption)
                    }
                }
            } else {
                // Recording state - shows delete, pause/resume, and save
                Button(action: deleteRecording) {
                    VStack {
                        Image(systemName: "trash.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("Delete")
                            .font(.caption)
                    }
                }
                
                Button(action: togglePause) {
                    VStack {
                        Image(systemName: isPaused ? "play.circle.fill" : "pause.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        Text(isPaused ? "Resume" : "Pause")
                            .font(.caption)
                    }
                }
                
                Button(action: saveRecording) {
                    VStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        Text("Save")
                            .font(.caption)
                    }
                }
            }
        }
        .padding(.vertical, 30)
    }
    
    // MARK: - Helper Views
    private var audioWaveform: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(Array(bufferEnergy.enumerated()), id: \.offset) { index, energy in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue.opacity(energy > 0.3 ? 1 : 0.5))
                        .frame(width: 3, height: CGFloat(energy) * 50)
                }
            }
            .frame(height: 50)
        }
    }
    
    // MARK: - Recording Control Functions
    private func startRecording() {
        Task {
            try? await speechManager.startRecording()
            isRecording = true
            isPaused = false
            startTimer()
            startWaveformUpdates()
        }
    }
    
    private func togglePause() {
        isPaused.toggle()
        if isPaused {
            stopTimer()
            speechManager.stopRecording()
        } else {
            Task {
                try? await speechManager.startRecording()
                startTimer()
            }
        }
    }
    
    private func deleteRecording() {
        // Add confirmation dialog
        stopEverything()
        // Clear transcribed text
        // Reset all states
    }
    
    private func saveRecording() {
        // Add saving logic
        stopEverything()
        // Add to saved recordings
        // Navigate back or show success message
    }
    
    private func stopEverything() {
        isRecording = false
        isPaused = false
        stopTimer()
        stopWaveformUpdates()
        speechManager.stopRecording()
        elapsedTime = 0
    }
    
    // MARK: - Helper Functions
    private func startTimer() {
        elapsedTime = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            DispatchQueue.main.async {
                self.elapsedTime += 1
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func startWaveformUpdates() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if self.speechManager.isRecording {
                DispatchQueue.main.async {
                    self.bufferEnergy.append(Float.random(in: 0...1))
                    if self.bufferEnergy.count > 50 {
                        self.bufferEnergy = Array(self.bufferEnergy.suffix(50))
                    }
                }
            } else {
                timer.invalidate()
            }
        }
    }
    
    private func stopWaveformUpdates() {
        bufferEnergy.removeAll()
    }
    
    private func formatDuration(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - History List View
struct RecordingHistoryView: View {
    @Binding var recordings: [SavedRecording]
    
    var body: some View {
        List {
            ForEach(recordings) { recording in
                VStack(alignment: .leading, spacing: 8) {
                    Text(recording.title)
                        .font(.headline)
                    
                    HStack {
                        Text(recording.date, style: .date)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(formatDuration(recording.duration))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(recording.transcript.prefix(100) + "...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Saved Recordings")
    }
    
    private func formatDuration(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Main View
struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showMenu = false
    @State private var savedRecordings: [SavedRecording] = [
        SavedRecording(title: "Meeting Notes", date: Date().addingTimeInterval(-86400), duration: 120, transcript: "This is a sample transcript..."),
        SavedRecording(title: "Quick Reminder", date: Date().addingTimeInterval(-43200), duration: 45, transcript: "Remember to follow up..."),
        SavedRecording(title: "Interview", date: Date(), duration: 1800, transcript: "Q&A session transcript...")
    ]
    
    var body: some View {
        NavigationStack {
            RecordingView()
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { showMenu.toggle() }) {
                            Image(systemName: "line.3.horizontal")
                        }
                    }
                }
        }
        .sheet(isPresented: $showMenu, onDismiss: nil) {
            NavigationView {
                RecordingHistoryView(recordings: $savedRecordings)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}

#Preview {
    ContentView()
}
