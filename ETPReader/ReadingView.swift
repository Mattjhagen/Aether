import SwiftUI
import SwiftData

public struct ReadingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var document: Document
    
    @StateObject private var speechManager = SpeechManager()
    
    // Display controls / focus state
    @State private var isFocusMode: Bool = false
    @State private var showSettings: Bool = false
    
    // User reading preferences (backed by UserDefaults)
    @State private var fontSize: CGFloat = 22
    @State private var lineSpacing: CGFloat = 8
    @State private var marginSize: CGFloat = 24
    @State private var selectedFont: ReadingFont = .georgia
    
    public init(document: Document) {
        self.document = document
    }
    
    public var body: some View {
        ZStack {
            // Dark Mode Background
            Color.metroBlack
                .ignoresSafeArea()
            
            // Core Text View
            GeometryReader { geometry in
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 24) {
                            
                            // Visual Margin Spacer at the Top
                            Spacer()
                                .frame(height: isFocusMode ? 60 : 100)
                            
                            // Book Header (only visible when not in Focus Mode)
                            if !isFocusMode {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(document.title.uppercased())
                                        .font(.system(size: 28, weight: .black))
                                        .foregroundColor(.metroWhite)
                                        .tracking(-0.5)
                                    
                                    Text(document.author)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.metroLightGray)
                                        .tracking(1)
                                    
                                    Divider()
                                        .background(Color.metroGray)
                                        .padding(.vertical, 16)
                                }
                                .padding(.horizontal, marginSize)
                            }
                            
                            // Render book sentences
                            if speechManager.sentences.isEmpty {
                                Text("This document contains no readable text.")
                                    .font(selectedFont.font(size: fontSize))
                                    .foregroundColor(.metroLightGray)
                                    .padding(.horizontal, marginSize)
                            } else {
                                ForEach(0..<speechManager.sentences.count, id: \.self) { index in
                                    let sentenceText = speechManager.sentences[index]
                                    let isActive = index == speechManager.currentSentenceIndex
                                    
                                    SentenceItemView(
                                        text: sentenceText,
                                        index: index,
                                        isActive: isActive,
                                        isPlaying: speechManager.isPlaying,
                                        currentWordRange: speechManager.currentWordRange,
                                        font: selectedFont,
                                        fontSize: fontSize,
                                        lineSpacing: lineSpacing
                                    )
                                    .id(index)
                                    .padding(.horizontal, marginSize)
                                    .onTapGesture {
                                        // Tap on a sentence jumps the speech manager to that sentence
                                        speechManager.jumpToSentence(index: index)
                                    }
                                }
                            }
                            
                            // Visual Spacer at the Bottom
                            Spacer()
                                .frame(height: isFocusMode ? 120 : 200)
                        }
                    }
                    .coordinateSpace(name: "scroll")
                    .gesture(
                        // Tap Gestures on ScrollView:
                        // Double Tap -> Toggle Focus Mode
                        // Single Tap -> If Focus Mode, reveal controls
                        TapGesture(count: 2)
                            .onEnded {
                                withAnimation(.metroFocus) {
                                    isFocusMode.toggle()
                                }
                            }
                            .simultaneously(
                                with: TapGesture(count: 1)
                                    .onEnded {
                                        if isFocusMode {
                                            withAnimation(.metroFocus) {
                                                isFocusMode = false
                                            }
                                        }
                                    }
                            )
                    )
                    // Listen to progress updates to keep spoken sentence centered
                    .onChange(of: speechManager.currentSentenceIndex) { _, newIndex in
                        if speechManager.isPlaying {
                            withAnimation(.metroFocus) {
                                proxy.scrollTo(newIndex, anchor: .center)
                            }
                        }
                    }
                    .onAppear {
                        // Load saved preferences
                        loadPreferences()
                        
                        // Mark book as active read date
                        document.dateLastRead = Date()
                        try? modelContext.save()
                        
                        // Load document content in SpeechManager
                        let startSentence = document.readingProgress?.currentSentenceIndex ?? 0
                        speechManager.loadDocument(
                            id: document.id,
                            text: document.rawText,
                            startIndex: startSentence
                        ) { sentenceIndex in
                            // Update SwiftData progress as user reads
                            if let progress = document.readingProgress {
                                progress.currentSentenceIndex = sentenceIndex
                                try? modelContext.save()
                            }
                        }
                        
                        // Scroll to last read sentence on load
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            proxy.scrollTo(startSentence, anchor: .center)
                        }
                    }
                }
            }
            .ignoresSafeArea()
            
            // Custom Navigation Header (Hidden in Focus Mode)
            if !isFocusMode {
                VStack {
                    HStack {
                        Button(action: {
                            speechManager.stop()
                            dismiss()
                        }) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.metroWhite)
                                .frame(width: 44, height: 44)
                                .background(Color.metroBlack.opacity(0.8))
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            document.isFavorite.toggle()
                            try? modelContext.save()
                        }) {
                            Image(systemName: document.isFavorite ? "star.fill" : "star")
                                .font(.system(size: 18))
                                .foregroundColor(document.isFavorite ? .metroWhite : .metroSilver)
                                .frame(width: 44, height: 44)
                                .background(Color.metroBlack.opacity(0.8))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 50)
                    Spacer()
                }
                .ignoresSafeArea()
            }
            
            // Playback controls drawer (Bottom Panel)
            if !isFocusMode {
                VStack {
                    Spacer()
                    
                    VStack(spacing: 20) {
                        
                        // Voice & Speed HUD
                        HStack {
                            // Voice Selector Menu
                            Menu {
                                ForEach(speechManager.availableVoices, id: \.identifier) { voice in
                                    Button(action: {
                                        speechManager.selectedVoice = voice
                                    }) {
                                        HStack {
                                            Text("\(voice.name) (\(voice.language))")
                                            if speechManager.selectedVoice?.identifier == voice.identifier {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "person.wave.2")
                                    Text(speechManager.selectedVoice?.name ?? "Siri Voice")
                                        .lineLimit(1)
                                }
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.metroSilver)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.metroGray)
                                .border(Color.metroLightGray.opacity(0.2), width: 1)
                            }
                            
                            Spacer()
                            
                            // Speed Controls Menu
                            Menu {
                                ForEach([0.75, 1.0, 1.25, 1.5, 1.75, 2.0], id: \.self) { speed in
                                    Button(action: {
                                        speechManager.speedMultiplier = speed
                                    }) {
                                        HStack {
                                            Text(String(format: "%.2fx", speed))
                                            if speechManager.speedMultiplier == speed {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "speedometer")
                                    Text(String(format: "%.2fx", speechManager.speedMultiplier))
                                }
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.metroSilver)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.metroGray)
                                .border(Color.metroLightGray.opacity(0.2), width: 1)
                            }
                        }
                        .padding(.horizontal, 8)
                        
                        // Media Buttons
                        HStack(spacing: 40) {
                            Button(action: {
                                speechManager.skipBackward()
                            }) {
                                Image(systemName: "gobackward.10")
                                    .font(.system(size: 22, weight: .light))
                                    .foregroundColor(.metroWhite)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Button(action: {
                                if speechManager.isPlaying {
                                    speechManager.pause()
                                } else {
                                    speechManager.play()
                                }
                            }) {
                                Image(systemName: speechManager.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.metroWhite)
                                    .frame(width: 72, height: 72)
                                    .background(Color.metroGray)
                                    .border(Color.metroLightGray.opacity(0.4), width: 1)
                            }
                            .buttonStyle(MetroTileButtonStyle())
                            
                            Button(action: {
                                speechManager.skipForward()
                            }) {
                                Image(systemName: "goforward.10")
                                    .font(.system(size: 22, weight: .light))
                                    .foregroundColor(.metroWhite)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        // Options Toggle
                        HStack {
                            Spacer()
                            Button(action: {
                                withAnimation(.metroTransition) {
                                    showSettings.toggle()
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "textformat.size")
                                    Text("DISPLAY OPTIONS")
                                }
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1)
                                .foregroundColor(.metroLightGray)
                            }
                            Spacer()
                        }
                        .padding(.top, 4)
                    }
                    .padding(24)
                    .background(Color.metroBlack)
                    .border(Color.metroCharcoal, width: 2)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 34)
                }
                .ignoresSafeArea()
            }
            
            // Custom Settings Overlay Sheet (Display Options)
            if showSettings {
                ZStack {
                    // Dim Background
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.metroTransition) {
                                showSettings = false
                            }
                        }
                    
                    VStack {
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 24) {
                            HStack {
                                Text("DISPLAY SETTINGS")
                                    .font(.system(size: 12, weight: .bold))
                                    .tracking(2)
                                    .foregroundColor(.metroSilver)
                                Spacer()
                                Button(action: {
                                    withAnimation(.metroTransition) {
                                        showSettings = false
                                    }
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.footnote)
                                        .foregroundColor(.metroWhite)
                                        .padding(8)
                                        .background(Color.metroGray)
                                }
                            }
                            .padding(.bottom, 8)
                            
                            // Font Selection
                            VStack(alignment: .leading, spacing: 10) {
                                Text("TYPEFACE")
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(1)
                                    .foregroundColor(.metroLightGray)
                                
                                HStack(spacing: 12) {
                                    ForEach(ReadingFont.allCases) { rFont in
                                        Button(action: {
                                            selectedFont = rFont
                                            savePreferences()
                                        }) {
                                            Text(rFont.rawValue)
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(selectedFont == rFont ? .metroWhite : .metroLightGray)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 12)
                                                .background(selectedFont == rFont ? Color.metroGray : Color.clear)
                                                .border(selectedFont == rFont ? Color.metroWhite : Color.metroGray, width: 1)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                            
                            // Font Size Slider
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("SIZE")
                                        .font(.system(size: 10, weight: .bold))
                                        .tracking(1)
                                        .foregroundColor(.metroLightGray)
                                    Spacer()
                                    Text("\(Int(fontSize))pt")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.metroWhite)
                                }
                                
                                Slider(value: $fontSize, in: 16...36, step: 2) { _ in
                                    savePreferences()
                                }
                                .accentColor(.metroWhite)
                            }
                            
                            // Line Spacing Slider
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("LINE HEIGHT")
                                        .font(.system(size: 10, weight: .bold))
                                        .tracking(1)
                                        .foregroundColor(.metroLightGray)
                                    Spacer()
                                    Text("\(Int(lineSpacing))pt")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.metroWhite)
                                }
                                
                                Slider(value: $lineSpacing, in: 4...16, step: 2) { _ in
                                    savePreferences()
                                }
                                .accentColor(.metroWhite)
                            }
                            
                            // Margins
                            VStack(alignment: .leading, spacing: 10) {
                                Text("MARGINS")
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(1)
                                    .foregroundColor(.metroLightGray)
                                
                                HStack(spacing: 12) {
                                    ForEach([16, 24, 32, 48], id: \.self) { margin in
                                        Button(action: {
                                            marginSize = CGFloat(margin)
                                            savePreferences()
                                        }) {
                                            Text("\(margin)px")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(marginSize == CGFloat(margin) ? .metroWhite : .metroLightGray)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 10)
                                                .background(marginSize == CGFloat(margin) ? Color.metroGray : Color.clear)
                                                .border(marginSize == CGFloat(margin) ? Color.metroWhite : Color.metroGray, width: 1)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                        }
                        .padding(24)
                        .background(Color.metroBlack)
                        .border(Color.metroGray, width: 1)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 40)
                    }
                }
                .transition(.move(edge: .bottom))
            }
        }
        .navigationBarHidden(true)
        .onDisappear {
            speechManager.stop()
        }
    }
    
    // MARK: - Save/Load Preferences
    private func savePreferences() {
        UserDefaults.standard.set(fontSize, forKey: "etp_font_size")
        UserDefaults.standard.set(lineSpacing, forKey: "etp_line_spacing")
        UserDefaults.standard.set(marginSize, forKey: "etp_margin_size")
        UserDefaults.standard.set(selectedFont.rawValue, forKey: "etp_selected_font")
    }
    
    private func loadPreferences() {
        if let size = UserDefaults.standard.value(forKey: "etp_font_size") as? CGFloat {
            fontSize = size
        }
        if let spacing = UserDefaults.standard.value(forKey: "etp_line_spacing") as? CGFloat {
            lineSpacing = spacing
        }
        if let margin = UserDefaults.standard.value(forKey: "etp_margin_size") as? CGFloat {
            marginSize = margin
        }
        if let rawFont = UserDefaults.standard.string(forKey: "etp_selected_font"),
           let rFont = ReadingFont(rawValue: rawFont) {
            selectedFont = rFont
        }
    }
}

// MARK: - Sentence Item Row Component
struct SentenceItemView: View {
    var text: String
    var index: Int
    var isActive: Bool
    var isPlaying: Bool
    var currentWordRange: NSRange?
    var font: ReadingFont
    var fontSize: CGFloat
    var lineSpacing: CGFloat
    
    var body: some View {
        Group {
            if isActive && isPlaying {
                // High contrast highlight of currently spoken word
                Text(highlightActiveSentence(text: text, range: currentWordRange))
                    .font(font.font(size: fontSize))
                    .lineSpacing(lineSpacing)
                    .foregroundColor(.metroWhite)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                // Ambient dimming of surrounding content
                Text(text)
                    .font(font.font(size: fontSize))
                    .lineSpacing(lineSpacing)
                    .foregroundColor(isPlaying ? .metroTextMuted : .metroWhite)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .opacity(isPlaying ? 0.45 : 1.0)
            }
        }
        // Smooth transition when entering/exiting reading focus
        .animation(.metroFocus, value: isPlaying)
        .animation(.metroFocus, value: isActive)
    }
    
    private func highlightActiveSentence(text: String, range: NSRange?) -> AttributedString {
        var attrStr = AttributedString(text)
        
        // Base active sentence color is light silver
        attrStr.foregroundColor = .metroSilver
        
        guard let range = range,
              let wordRange = text.rangeFromNSRange(range),
              let attrRange = attrStr.range(of: text[wordRange]) else {
            return attrStr
        }
        
        // Highlight active word in pure white and bold
        attrStr[attrRange].foregroundColor = .metroWordHighlight
        attrStr[attrRange].font = font.font(size: fontSize).bold()
        
        return attrStr
    }
}
