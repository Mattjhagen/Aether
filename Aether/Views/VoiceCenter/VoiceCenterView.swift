import SwiftUI
import SwiftData
import AVFoundation

public struct VoiceCenterView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var voiceService = VoiceService.shared
    
    @State private var selectedLanguage: String = "en-US"
    @State private var selectedVoiceIdentifier: String = ""
    @State private var speedMultiplier: Double = 1.0
    @State private var pitchMultiplier: Float = 1.0
    
    @State private var showPersonalVoiceOnboarding: Bool = false
    
    // Fetch SwiftData VoiceProfile
    private var activeProfile: VoiceProfile? {
        let descriptor = FetchDescriptor<VoiceProfile>()
        return (try? modelContext.fetch(descriptor))?.first
    }
    
    // Filter voices based on selected language
    private var filteredVoices: [AVSpeechSynthesisVoice] {
        voiceService.availableVoices.filter { $0.language == selectedLanguage }
    }
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color.metroBlack
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 32) {
                        
                        // Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text("AETHER")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(3)
                                .foregroundColor(.metroSilver)
                            Text("VOICE CENTER")
                                .font(.system(size: 36, weight: .black))
                                .foregroundColor(.metroWhite)
                                .tracking(-1)
                        }
                        .padding(.top, 24)
                        
                        // 1. Language Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("LANGUAGE")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(2)
                                .foregroundColor(.metroLightGray)
                            
                            Picker("Select Language", selection: $selectedLanguage) {
                                ForEach(voiceService.languages, id: \.self) { lang in
                                    Text(Locale.current.localizedString(forIdentifier: lang) ?? lang)
                                        .tag(lang)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .foregroundColor(.metroWhite)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .background(Color.metroCharcoal)
                            .border(Color.metroGray, width: 1)
                        }
                        
                        // 2. Personal Voice Section (Apple-quality visual highlight)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("PERSONAL VOICE")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(2)
                                .foregroundColor(.metroLightGray)
                            
                            if voiceService.personalVoices.isEmpty {
                                Button(action: {
                                    showPersonalVoiceOnboarding = true
                                }) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text("Personal Voice is not enabled.")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(.metroWhite)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.footnote)
                                                .foregroundColor(.metroLightGray)
                                        }
                                        Text("Tap to learn how to create and authorize a custom voice replica of yourself.")
                                            .font(.system(size: 12))
                                            .foregroundColor(.metroLightGray)
                                            .multilineTextAlignment(.leading)
                                    }
                                    .padding(20)
                                    .background(Color.metroCharcoal)
                                    .border(Color.metroGray, width: 1)
                                }
                                .buttonStyle(MetroTileButtonStyle())
                            } else {
                                Picker("Select Personal Voice", selection: $selectedVoiceIdentifier) {
                                    Text("Select Personal Voice...").tag("")
                                    ForEach(voiceService.personalVoices, id: \.identifier) { voice in
                                        Text(voice.name)
                                            .tag(voice.identifier)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .foregroundColor(.metroWhite)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .background(Color.metroCharcoal)
                                .border(Color.metroWhite.opacity(0.3), width: 1)
                            }
                        }
                        
                        // 3. Voice Selection Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("SYSTEM & SIRI VOICES")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(2)
                                .foregroundColor(.metroLightGray)
                            
                            if filteredVoices.isEmpty {
                                Text("No voices available for this language.")
                                    .font(.system(size: 13))
                                    .foregroundColor(.metroLightGray)
                                    .padding()
                            } else {
                                ForEach(filteredVoices, id: \.identifier) { voice in
                                    Button(action: {
                                        selectedVoiceIdentifier = voice.identifier
                                        saveProfile()
                                    }) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(voice.name)
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundColor(.metroWhite)
                                                
                                                Text(voice.quality == .premium ? "Premium Quality" : (voice.quality == .enhanced ? "Enhanced Quality" : "Standard Quality"))
                                                    .font(.system(size: 11))
                                                    .foregroundColor(.metroLightGray)
                                            }
                                            
                                            Spacer()
                                            
                                            if selectedVoiceIdentifier == voice.identifier {
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(.metroWhite)
                                                    .font(.footnote)
                                            }
                                        }
                                        .padding(16)
                                        .background(selectedVoiceIdentifier == voice.identifier ? Color.metroGray : Color.metroCharcoal)
                                        .border(selectedVoiceIdentifier == voice.identifier ? Color.metroWhite : Color.metroGray, width: 1)
                                    }
                                    .buttonStyle(MetroTileButtonStyle())
                                }
                            }
                        }
                        
                        // 4. Rate & Pitch settings
                        VStack(alignment: .leading, spacing: 20) {
                            // Rate Setting
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("SPEAKING RATE")
                                        .font(.system(size: 10, weight: .bold))
                                        .tracking(2)
                                        .foregroundColor(.metroLightGray)
                                    Spacer()
                                    Text(String(format: "%.2fx", speedMultiplier))
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.metroWhite)
                                }
                                
                                Slider(value: $speedMultiplier, in: 0.5...2.0, step: 0.1) { _ in
                                    saveProfile()
                                }
                                .accentColor(.metroWhite)
                            }
                            
                            // Pitch Setting
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("PITCH")
                                        .font(.system(size: 10, weight: .bold))
                                        .tracking(2)
                                        .foregroundColor(.metroLightGray)
                                    Spacer()
                                    Text(String(format: "%.1f", pitchMultiplier))
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.metroWhite)
                                }
                                
                                Slider(value: $pitchMultiplier, in: 0.5...2.0, step: 0.1) { _ in
                                    saveProfile()
                                }
                                .accentColor(.metroWhite)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                voiceService.loadVoices()
                loadProfile()
            }
            .sheet(isPresented: $showPersonalVoiceOnboarding) {
                PersonalVoiceOnboardingView()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.metroWhite)
                    .font(.system(size: 14, weight: .bold))
                }
            }
        }
    }
    
    // Save/Load Settings
    private func loadProfile() {
        if let profile = activeProfile {
            self.selectedLanguage = profile.language
            self.selectedVoiceIdentifier = profile.voiceIdentifier
            self.speedMultiplier = profile.speedMultiplier
            self.pitchMultiplier = profile.pitchMultiplier
        } else {
            // Default settings
            let preferredLanguage = Locale.preferredLanguages.first ?? "en-US"
            self.selectedLanguage = preferredLanguage
            
            // Choose first available voice in preferred language
            if let firstVoice = voiceService.availableVoices.first(where: { $0.language == preferredLanguage }) {
                self.selectedVoiceIdentifier = firstVoice.identifier
            }
        }
    }
    
    private func saveProfile() {
        let profile = activeProfile ?? VoiceProfile()
        profile.language = selectedLanguage
        profile.voiceIdentifier = selectedVoiceIdentifier
        profile.speedMultiplier = speedMultiplier
        profile.pitchMultiplier = pitchMultiplier
        
        if activeProfile == nil {
            modelContext.insert(profile)
        }
        try? modelContext.save()
    }
}
