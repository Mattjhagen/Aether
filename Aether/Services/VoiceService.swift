import Foundation
import AVFoundation
import Combine
import UIKit

public class VoiceService: ObservableObject {
    @Published public var availableVoices: [AVSpeechSynthesisVoice] = []
    @Published public var personalVoices: [AVSpeechSynthesisVoice] = []
    @Published public var languages: [String] = []
    
    // Shared singleton for global settings
    public static let shared = VoiceService()
    
    private init() {
        loadVoices()
    }
    
    public func loadVoices() {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        self.availableVoices = allVoices
        
        // Get unique languages sorted
        let uniqueLanguages = Set(allVoices.map { $0.language })
        self.languages = Array(uniqueLanguages).sorted()
        
        // Filter personal voices on iOS 17+ using voiceTraits
        if #available(iOS 17.0, *) {
            self.personalVoices = allVoices.filter { $0.voiceTraits.contains(.isPersonalVoice) }
        } else {
            self.personalVoices = []
        }
    }
    
    public func requestPersonalVoiceAuthorization(completion: @escaping (Bool) -> Void) {
        if #available(iOS 17.0, *) {
            AVSpeechSynthesizer.requestPersonalVoiceAuthorization { status in
                DispatchQueue.main.async {
                    self.loadVoices()
                    completion(status == .authorized)
                }
            }
        } else {
            completion(false)
        }
    }
    
    public func openSettings() {
        // iOS URL Scheme for accessibility settings or general settings
        let urlStrings = [
            "App-Prefs:root=ACCESSIBILITY&path=PERSONAL_VOICE",
            "App-Prefs:root=ACCESSIBILITY",
            UIApplication.openSettingsURLString
        ]
        
        for urlString in urlStrings {
            if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
                return
            }
        }
    }
}
