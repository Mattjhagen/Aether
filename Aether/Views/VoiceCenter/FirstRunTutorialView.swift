import SwiftUI
import AVFoundation

public struct FirstRunTutorialView: View {
    @Binding var hasCompletedOnboarding: Bool
    @StateObject private var voiceService = VoiceService.shared
    
    @State private var currentStep: Int = 0
    @State private var authStatus: String = "Not Authorized"
    @State private var isAuthorizing: Bool = false
    
    public init(hasCompletedOnboarding: Binding<Bool>) {
        self._hasCompletedOnboarding = hasCompletedOnboarding
    }
    
    public var body: some View {
        ZStack {
            Color.metroBlack
                .ignoresSafeArea()
            
            VStack {
                // Top Skip / Progress Bar
                HStack(spacing: 8) {
                    ForEach(0..<4) { index in
                        Rectangle()
                            .fill(index == currentStep ? Color.metroWhite : Color.metroGray)
                            .frame(height: 3)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                
                Spacer()
                
                // Content Switcher
                Group {
                    switch currentStep {
                    case 0:
                        WelcomeStep()
                    case 1:
                        PersonalVoiceExplanationStep()
                    case 2:
                        SettingsSetupStep(openSettings: {
                            voiceService.openSettings()
                        })
                    case 3:
                        AuthorizationStep(
                            isAuthorizing: $isAuthorizing,
                            authStatus: $authStatus,
                            requestAuth: {
                                isAuthorizing = true
                                voiceService.requestPersonalVoiceAuthorization { success in
                                    isAuthorizing = false
                                    authStatus = success ? "Authorized" : "Denied"
                                }
                            },
                            startReading: {
                                withAnimation {
                                    hasCompletedOnboarding = true
                                }
                            }
                        )
                    default:
                        EmptyView()
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                    removal: .opacity.combined(with: .move(edge: .leading))
                ))
                .animation(.metroFocus, value: currentStep)
                
                Spacer()
                
                // Navigation Bar
                HStack {
                    if currentStep > 0 {
                        Button(action: {
                            withAnimation {
                                currentStep -= 1
                            }
                        }) {
                            Text("BACK")
                                .font(.system(size: 13, weight: .bold))
                                .tracking(1)
                                .foregroundColor(.metroLightGray)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 16)
                                .border(Color.metroGray, width: 1)
                        }
                    } else {
                        Button(action: {
                            withAnimation {
                                hasCompletedOnboarding = true
                            }
                        }) {
                            Text("SKIP")
                                .font(.system(size: 13, weight: .bold))
                                .tracking(1)
                                .foregroundColor(.metroLightGray)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 16)
                        }
                    }
                    
                    Spacer()
                    
                    if currentStep < 3 {
                        Button(action: {
                            withAnimation {
                                currentStep += 1
                            }
                        }) {
                            HStack {
                                Text("CONTINUE")
                                    .font(.system(size: 13, weight: .bold))
                                    .tracking(1)
                                Image(systemName: "arrow.right")
                                    .font(.footnote)
                            }
                            .foregroundColor(.metroBlack)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 16)
                            .background(Color.metroWhite)
                        }
                        .buttonStyle(MetroTileButtonStyle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }
}

// MARK: - Welcome Step View
struct WelcomeStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("WELCOME")
                .font(.system(size: 11, weight: .bold))
                .tracking(4)
                .foregroundColor(.metroSilver)
            
            Text("AETHER")
                .font(.system(size: 56, weight: .black))
                .foregroundColor(.metroWhite)
                .tracking(-2)
            
            Text("Aether is an immersive reading experience designed for ultimate focus. Read and listen to your library in a completely minimalist, distraction-free environment.")
                .font(.system(size: 16))
                .foregroundColor(.metroLightGray)
                .lineSpacing(6)
            
            VStack(alignment: .leading, spacing: 14) {
                FeatureBullet(icon: "waveform", text: "Read using your own Personal Voice replica")
                FeatureBullet(icon: "text.alignleft", text: "Customize typography, spacing, and layouts")
                FeatureBullet(icon: "eye.slash", text: "Focus Mode hides all controls during reading")
            }
            .padding(.top, 16)
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - Personal Voice Explanation Step
struct PersonalVoiceExplanationStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("THE MAIN FEATURE")
                .font(.system(size: 11, weight: .bold))
                .tracking(3)
                .foregroundColor(.metroSilver)
            
            Text("READ IN YOUR OWN VOICE")
                .font(.system(size: 38, weight: .black))
                .foregroundColor(.metroWhite)
                .tracking(-1)
                .lineLimit(2)
            
            Text("Aether's signature capability lets you (or a loved one) use Apple's \"Personal Voice\" technology to read your books aloud. This creates an incredibly intimate and comfortable learning experience.")
                .font(.system(size: 16))
                .foregroundColor(.metroLightGray)
                .lineSpacing(6)
            
            Text("Personal Voice is completely processed on-device by iOS, keeping your data secure, private, and offline.")
                .font(.system(size: 14))
                .foregroundColor(.metroLightGray)
                .lineSpacing(4)
                .padding(.top, 8)
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - Settings Setup Step
struct SettingsSetupStep: View {
    var openSettings: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("GUIDE & TUTORIAL")
                .font(.system(size: 11, weight: .bold))
                .tracking(3)
                .foregroundColor(.metroSilver)
            
            Text("SET UP PERSONAL VOICE")
                .font(.system(size: 34, weight: .black))
                .foregroundColor(.metroWhite)
                .tracking(-1)
            
            VStack(alignment: .leading, spacing: 14) {
                InstructionRow(number: "1", text: "Open iOS Settings")
                InstructionRow(number: "2", text: "Navigate to Accessibility > Personal Voice")
                InstructionRow(number: "3", text: "Tap \"Create a Personal Voice\" and record your voice phrases")
                InstructionRow(number: "4", text: "iOS generates your replica voice securely overnight while charging")
            }
            .padding(.vertical, 8)
            
            Button(action: openSettings) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.forward.app")
                    Text("OPEN IOS SETTINGS")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                }
                .foregroundColor(.metroWhite)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .border(Color.metroWhite, width: 1)
            }
            .buttonStyle(MetroTileButtonStyle())
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - Authorization Step View
struct AuthorizationStep: View {
    @Binding var isAuthorizing: Bool
    @Binding var authStatus: String
    var requestAuth: () -> Void
    var startReading: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("FINAL STEP")
                .font(.system(size: 11, weight: .bold))
                .tracking(3)
                .foregroundColor(.metroSilver)
            
            Text("GRANT VOICE ACCESS")
                .font(.system(size: 36, weight: .black))
                .foregroundColor(.metroWhite)
                .tracking(-1)
            
            Text("Aether requires your permission to read documents with your Personal Voice. Allow authorization to list it in our Voice Center.")
                .font(.system(size: 15))
                .foregroundColor(.metroLightGray)
                .lineSpacing(6)
            
            VStack(spacing: 12) {
                if authStatus == "Authorized" {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                        Text("PERSONAL VOICE ENABLED")
                            .font(.system(size: 12, weight: .bold))
                            .tracking(1)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.metroGray)
                    .border(Color.metroWhite, width: 1)
                } else {
                    Button(action: requestAuth) {
                        HStack(spacing: 8) {
                            if isAuthorizing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .metroBlack))
                            } else {
                                Image(systemName: "lock.open")
                            }
                            Text(authStatus == "Denied" ? "SETTINGS (DENIED)" : "AUTHORIZE PERSONAL VOICE")
                                .font(.system(size: 12, weight: .bold))
                                .tracking(1)
                        }
                        .foregroundColor(.metroBlack)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                        .background(Color.metroWhite)
                    }
                    .buttonStyle(MetroTileButtonStyle())
                    .disabled(isAuthorizing)
                }
                
                Button(action: startReading) {
                    Text("START READING")
                        .font(.system(size: 13, weight: .bold))
                        .tracking(1)
                        .foregroundColor(.metroWhite)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                        .border(authStatus == "Authorized" ? Color.metroWhite : Color.metroGray, width: 1)
                }
                .buttonStyle(MetroTileButtonStyle())
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - Feature Bullet View Helper
struct FeatureBullet: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.metroWhite)
                .frame(width: 24, height: 24)
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.metroSilver)
        }
    }
}

// MARK: - Instruction Row Helper
struct InstructionRow: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.metroBlack)
                .frame(width: 20, height: 20)
                .background(Color.metroWhite)
                .clipShape(Circle())
            
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.metroSilver)
                .lineSpacing(3)
        }
    }
}
