import Foundation
import AVFoundation
import NaturalLanguage
import Combine

public struct ChapterLink: Identifiable, Hashable {
    public let id: UUID
    public let title: String
    public let sentenceIndex: Int
    
    public init(id: UUID = UUID(), title: String, sentenceIndex: Int) {
        self.id = id
        self.title = title
        self.sentenceIndex = sentenceIndex
    }
}

public class ReaderSyncService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    
    @Published public var isPlaying: Bool = false
    @Published public var currentSentenceIndex: Int = 0
    @Published public var currentWordRange: NSRange? = nil
    @Published public var chapters: [ChapterLink] = []
    
    // Configurable voice parameters
    @Published public var speedMultiplier: Double = 1.0 // 0.5x to 2.0x
    @Published public var pitchMultiplier: Float = 1.0 // 0.5 to 2.0
    @Published public var selectedVoice: AVSpeechSynthesisVoice?
    
    public var sentences: [String] = []
    private let synthesizer = AVSpeechSynthesizer()
    private var activeDocumentId: UUID?
    private var onProgressChange: ((Int) -> Void)?
    
    public override init() {
        super.init()
        self.synthesizer.delegate = self
        configureAudioSession()
        loadDefaultVoice()
    }
    
    private func loadDefaultVoice() {
        let preferredLanguage = Locale.preferredLanguages.first ?? "en-US"
        let baseLang = preferredLanguage.components(separatedBy: "-").first ?? "en"
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        
        let filtered = allVoices.filter { $0.language.hasPrefix(baseLang) }.sorted { v1, v2 in
            let q1 = v1.quality.rawValue
            let q2 = v2.quality.rawValue
            if q1 != q2 {
                return q1 > q2
            }
            return v1.name < v2.name
        }
        
        self.selectedVoice = filtered.first(where: {
            $0.quality == .enhanced || $0.name.contains("Siri") || $0.name.contains("Personal")
        }) ?? AVSpeechSynthesisVoice(language: preferredLanguage) ?? allVoices.first
    }
    
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
        } catch {
            print("Failed to configure audio session category: \(error)")
        }
    }
    
    private func activateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to activate audio session: \(error)")
        }
    }
    
    private func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
    }
    
    // MARK: - Playback Controls
    
    public func loadDocument(id: UUID, text: String, startIndex: Int, progressCallback: @escaping (Int) -> Void) {
        stop()
        
        self.activeDocumentId = id
        self.onProgressChange = progressCallback
        
        // Segment the document's text into sentences
        self.sentences = segmentTextIntoSentences(text)
        extractChapters()
        self.currentSentenceIndex = min(max(0, startIndex), max(0, sentences.count - 1))
        self.currentWordRange = nil
    }
    
    private func segmentTextIntoSentences(_ text: String) -> [String] {
        guard !text.isEmpty else { return [] }
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var list: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                list.append(sentence)
            }
            return true
        }
        return list.isEmpty ? [text] : list
    }
    
    private func extractChapters() {
        var links: [ChapterLink] = []
        for (index, sentence) in sentences.enumerated() {
            let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("#") {
                let cleanTitle = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "#").union(.whitespacesAndNewlines))
                links.append(ChapterLink(title: cleanTitle, sentenceIndex: index))
            } else if trimmed.uppercased().hasPrefix("CHAPTER ") || trimmed.uppercased().hasPrefix("PART ") {
                links.append(ChapterLink(title: trimmed, sentenceIndex: index))
            }
        }
        
        if links.isEmpty {
            links.append(ChapterLink(title: "Beginning", sentenceIndex: 0))
        }
        
        self.chapters = links
    }
    
    public func play() {
        guard !sentences.isEmpty else { return }
        
        activateAudioSession()
        
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
            isPlaying = true
        } else {
            speakCurrentSentence()
        }
    }
    
    public func pause() {
        guard isPlaying else { return }
        synthesizer.pauseSpeaking(at: .immediate)
        isPlaying = false
    }
    
    public func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
        currentWordRange = nil
        deactivateAudioSession()
    }
    
    public func skipForward() {
        guard !sentences.isEmpty else { return }
        let nextIndex = currentSentenceIndex + 1
        if nextIndex < sentences.count {
            jumpToSentence(index: nextIndex)
        } else {
            stop()
        }
    }
    
    public func skipBackward() {
        guard !sentences.isEmpty else { return }
        let prevIndex = currentSentenceIndex - 1
        if prevIndex >= 0 {
            jumpToSentence(index: prevIndex)
        } else {
            jumpToSentence(index: 0)
        }
    }
    
    public func jumpToSentence(index: Int) {
        guard !sentences.isEmpty else { return }
        let targetIndex = min(max(0, index), sentences.count - 1)
        
        let wasPlaying = isPlaying
        stop()
        
        self.currentSentenceIndex = targetIndex
        self.onProgressChange?(targetIndex)
        
        if wasPlaying {
            activateAudioSession()
            speakCurrentSentence()
        }
    }
    
    private func speakCurrentSentence() {
        guard currentSentenceIndex < sentences.count else {
            stop()
            return
        }
        
        let sentenceText = sentences[currentSentenceIndex]
        let utterance = AVSpeechUtterance(string: sentenceText)
        
        // Map speed multiplier (0.5x to 2.0x) to AVSpeechUtterance rate
        let rate: Float
        if speedMultiplier == 1.0 {
            rate = AVSpeechUtteranceDefaultSpeechRate
        } else if speedMultiplier < 1.0 {
            rate = Float(speedMultiplier) * AVSpeechUtteranceDefaultSpeechRate
        } else {
            let scale = (speedMultiplier - 1.0) / 1.0
            rate = AVSpeechUtteranceDefaultSpeechRate + Float(scale) * (AVSpeechUtteranceMaximumSpeechRate - AVSpeechUtteranceDefaultSpeechRate)
        }
        
        utterance.rate = max(AVSpeechUtteranceMinimumSpeechRate, min(AVSpeechUtteranceMaximumSpeechRate, rate))
        utterance.voice = selectedVoice
        utterance.pitchMultiplier = pitchMultiplier
        utterance.preUtteranceDelay = 0.05
        
        synthesizer.speak(utterance)
        isPlaying = true
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isPlaying = true
        }
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.currentWordRange = nil
            let nextIndex = self.currentSentenceIndex + 1
            if nextIndex < self.sentences.count {
                self.currentSentenceIndex = nextIndex
                self.onProgressChange?(nextIndex)
                self.speakCurrentSentence()
            } else {
                self.stop()
            }
        }
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.currentWordRange = nil
        }
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.currentWordRange = characterRange
        }
    }
}
