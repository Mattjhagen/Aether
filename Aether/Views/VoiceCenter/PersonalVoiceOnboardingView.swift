import SwiftUI

public struct PersonalVoiceOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var voiceService = VoiceService.shared
    @State private var authChecking = false
    @State private var authorized = false
    
    public init() {}
    
    public var body: some View {
        ZStack {
            Color.metroBlack
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 32) {
                // Header Block
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ONBOARDING")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(3)
                            .foregroundColor(.metroSilver)
                        
                        Text("PERSONAL VOICE")
                            .font(.system(size: 36, weight: .black))
                            .foregroundColor(.metroWhite)
                            .tracking(-1)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .foregroundColor(.metroWhite)
                            .padding(8)
                            .background(Color.metroGray)
                    }
                }
                .padding(.top, 24)
                
                Text("Personal Voice is a powerful iOS feature that uses machine learning to create a secure, synthesized replica of your voice. Once configured, Aether can read any document back to you in your own voice.")
                    .font(.system(size: 15))
                    .foregroundColor(.metroLightGray)
                    .lineSpacing(4)
                
                // Active Action Area
                VStack(spacing: 16) {
                    Button(action: {
                        authChecking = true
                        voiceService.requestPersonalVoiceAuthorization { success in
                            authChecking = false
                            authorized = success
                            if success {
                                // Close if successful
                                dismiss()
                            } else {
                                // Otherwise trigger deep linking to iOS Settings
                                voiceService.openSettings()
                            }
                        }
                    }) {
                        HStack {
                            if authChecking {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .metroBlack))
                                    .padding(.trailing, 8)
                            } else {
                                Image(systemName: "person.badge.key")
                            }
                            Text("AUTHORIZE & CONFIGURE")
                                .font(.system(size: 13, weight: .bold))
                                .tracking(1)
                        }
                        .foregroundColor(.metroBlack)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.metroWhite)
                    }
                    .buttonStyle(MetroTileButtonStyle())
                    .disabled(authChecking)
                }
                
                Divider()
                    .background(Color.metroGray)
                
                // Guided Instructions Section
                VStack(alignment: .leading, spacing: 20) {
                    Text("HOW TO ENABLE PERSONAL VOICE")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(2)
                        .foregroundColor(.metroSilver)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        InstructionStep(number: "1", text: "Open the system iOS Settings app.")
                        InstructionStep(number: "2", text: "Navigate to Accessibility.")
                        InstructionStep(number: "3", text: "Scroll down to Speech and select Personal Voice.")
                        InstructionStep(number: "4", text: "Tap Create a Personal Voice and follow the prompts to record. iOS will process your voice replica securely overnight while your iPhone is charging.")
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Instruction Step Helper
struct InstructionStep: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(number)
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundColor(.metroBlack)
                .frame(width: 24, height: 24)
                .background(Color.metroWhite)
                .clipShape(Circle())
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.metroLightGray)
                .lineSpacing(3)
                .padding(.top, 2)
        }
    }
}
