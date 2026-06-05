import SwiftUI
import SwiftData
import AVFoundation

public struct ReaderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var document: Document
    
    @StateObject private var syncService = ReaderSyncService()
    
    // Auto-hide and Focus mode state
    @State private var controlsVisible: Bool = true
    @State private var isFocusMode: Bool = false
    @State private var autoHideTimer: Timer? = nil
    
    // Settings & Chapters overlays
    @State private var showSettings: Bool = false
    @State private var showChapters: Bool = false
    
    // User reading preferences
    @State private var fontSize: CGFloat = 22
    @State private var lineSpacing: CGFloat = 8
    @State private var marginSize: CGFloat = 24
    @State private var selectedFont: ReadingFont = .georgia
    @State private var selectedBackdrop: ReaderBackdrop = .midnight
    @State private var selectedAlignment: ReadingAlignment = .leading
    @State private var selectedTracking: ReadingTracking = .normal
    @StateObject private var voiceService = VoiceService.shared
    
    public init(document: Document) {
        self.document = document
    }
    
    public var body: some View {
        ZStack {
            // Dynamic Backdrop Background
            selectedBackdrop.backgroundColor
                .ignoresSafeArea()
            
            // Core Text Scroll View
            GeometryReader { geometry in
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 24) {
                            
                            // Visual Margin Spacer at the Top
                            Spacer()
                                .frame(height: isFocusMode ? 60 : 120)
                            
                            // Header (Hidden in Focus Mode)
                            if !isFocusMode {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(document.title.uppercased())
                                        .font(.system(size: 28, weight: .black))
                                        .foregroundColor(selectedBackdrop.primaryTextColor)
                                        .tracking(-0.5)
                                    
                                    Text(document.author)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(selectedBackdrop.secondaryTextColor)
                                        .tracking(1)
                                    
                                    Divider()
                                        .background(selectedBackdrop.borderColor)
                                        .padding(.vertical, 16)
                                }
                                .padding(.horizontal, marginSize)
                                .opacity(controlsVisible ? 1.0 : 0.0)
                                .animation(.metroTransition, value: controlsVisible)
                            }
                            
                            // Sentences display
                            if syncService.sentences.isEmpty {
                                Text("This document contains no readable text.")
                                    .font(selectedFont.font(size: fontSize))
                                    .foregroundColor(selectedBackdrop.secondaryTextColor)
                                    .padding(.horizontal, marginSize)
                            } else {
                                ForEach(0..<syncService.sentences.count, id: \.self) { index in
                                    let sentenceText = syncService.sentences[index]
                                    let isActive = index == syncService.currentSentenceIndex
                                    
                                    SentenceItemView(
                                        text: sentenceText,
                                        index: index,
                                        isActive: isActive,
                                        isPlaying: syncService.isPlaying,
                                        currentWordRange: syncService.currentWordRange,
                                        font: selectedFont,
                                        fontSize: fontSize,
                                        lineSpacing: lineSpacing,
                                        backdrop: selectedBackdrop,
                                        alignment: selectedAlignment,
                                        tracking: selectedTracking
                                    )
                                    .id(index)
                                    .padding(.horizontal, marginSize)
                                    .onTapGesture {
                                        syncService.jumpToSentence(index: index)
                                        resetAutoHideTimer()
                                    }
                                }
                            }
                            
                            // Visual Spacer at the Bottom
                            Spacer()
                                .frame(height: isFocusMode ? 120 : 220)
                        }
                    }
                    .coordinateSpace(name: "scroll")
                    .onTapGesture(count: 2) {
                        withAnimation(.metroFocus) {
                            isFocusMode.toggle()
                            if isFocusMode {
                                controlsVisible = false
                            } else {
                                resetAutoHideTimer()
                            }
                        }
                    }
                    .onTapGesture(count: 1) {
                        withAnimation(.metroFocus) {
                            if isFocusMode {
                                isFocusMode = false
                                resetAutoHideTimer()
                            } else {
                                if controlsVisible {
                                    controlsVisible = false
                                } else {
                                    resetAutoHideTimer()
                                }
                            }
                        }
                    }
                    // Auto-scroll centering
                    .onChange(of: syncService.currentSentenceIndex) { _, newIndex in
                        withAnimation(.metroFocus) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                    .onAppear {
                        loadPreferences()
                        
                        // Register read timestamp
                        document.dateLastRead = Date()
                        try? modelContext.save()
                        
                        // Load saved speed, pitch, voice profile
                        loadVoiceProfile()
                        
                        // Load document content in Sync Service
                        let startSentence = document.readingProgress?.currentSentenceIndex ?? 0
                        syncService.loadDocument(
                            id: document.id,
                            text: document.rawText,
                            startIndex: startSentence
                        ) { sentenceIndex in
                            if let progress = document.readingProgress {
                                progress.currentSentenceIndex = sentenceIndex
                                try? modelContext.save()
                            }
                        }
                        
                        // Scroll to position
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            proxy.scrollTo(startSentence, anchor: .center)
                        }
                        
                        resetAutoHideTimer()
                    }
                }
            }
            .ignoresSafeArea()
            
            // Custom Navigation Header (Hidden in Focus Mode)
            if !isFocusMode && controlsVisible {
                VStack {
                    HStack {
                        Button(action: {
                            syncService.stop()
                            dismiss()
                        }) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(selectedBackdrop.primaryTextColor)
                                .frame(width: 44, height: 44)
                                .background(selectedBackdrop.panelBackgroundColor.opacity(0.8))
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            document.isFavorite.toggle()
                            try? modelContext.save()
                            resetAutoHideTimer()
                        }) {
                            Image(systemName: document.isFavorite ? "star.fill" : "star")
                                .font(.system(size: 18))
                                .foregroundColor(document.isFavorite ? selectedBackdrop.primaryTextColor : selectedBackdrop.secondaryTextColor)
                                .frame(width: 44, height: 44)
                                .background(selectedBackdrop.panelBackgroundColor.opacity(0.8))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 50)
                    Spacer()
                }
                .ignoresSafeArea()
                .transition(.opacity)
            }
            
            // Playback controls drawer (Bottom Panel, Hidden in Focus Mode)
            if !isFocusMode && controlsVisible {
                VStack {
                    Spacer()
                    
                    VStack(spacing: 20) {
                        // Progress Text HUD
                        Text(getRemainingTimeText())
                            .font(.system(size: 10, weight: .bold))
                            .tracking(2)
                            .foregroundColor(selectedBackdrop.secondaryTextColor)
                        
                        // Voice & Speed indicators
                        HStack {
                            Menu {
                                if !voiceService.personalVoices.isEmpty {
                                    Section("Personal Voices") {
                                        ForEach(voiceService.personalVoices, id: \.identifier) { voice in
                                            Button(action: {
                                                syncService.selectedVoice = voice
                                                saveVoiceProfile()
                                                resetAutoHideTimer()
                                            }) {
                                                HStack {
                                                    Text("🗣️ \(voice.name)")
                                                    if syncService.selectedVoice?.identifier == voice.identifier {
                                                        Image(systemName: "checkmark")
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                let siriVoices = voiceService.availableVoices.filter { $0.name.contains("Siri") }
                                if !siriVoices.isEmpty {
                                    Section("Siri Voices") {
                                        ForEach(siriVoices, id: \.identifier) { voice in
                                            Button(action: {
                                                syncService.selectedVoice = voice
                                                saveVoiceProfile()
                                                resetAutoHideTimer()
                                            }) {
                                                HStack {
                                                    Text("\(voice.name) (\(voice.language))")
                                                    if syncService.selectedVoice?.identifier == voice.identifier {
                                                        Image(systemName: "checkmark")
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                let systemVoices = voiceService.availableVoices.filter { !$0.name.contains("Siri") }
                                if !systemVoices.isEmpty {
                                    Section("System Voices") {
                                        ForEach(systemVoices.prefix(15), id: \.identifier) { voice in
                                            Button(action: {
                                                syncService.selectedVoice = voice
                                                saveVoiceProfile()
                                                resetAutoHideTimer()
                                            }) {
                                                HStack {
                                                    Text("\(voice.name) (\(voice.language))")
                                                    if syncService.selectedVoice?.identifier == voice.identifier {
                                                        Image(systemName: "checkmark")
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "person.wave.2")
                                    Text(syncService.selectedVoice?.name ?? "Voice")
                                        .lineLimit(1)
                                }
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(selectedBackdrop.primaryTextColor)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedBackdrop.panelBackgroundColor)
                                .border(selectedBackdrop.borderColor, width: 1)
                            }
                            
                            Spacer()
                            
                            Menu {
                                ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0], id: \.self) { speed in
                                    Button(action: {
                                        syncService.speedMultiplier = speed
                                        saveVoiceProfile()
                                        resetAutoHideTimer()
                                    }) {
                                        HStack {
                                            Text(String(format: "%.2fx", speed))
                                            if syncService.speedMultiplier == speed {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "speedometer")
                                    Text(String(format: "%.2fx", syncService.speedMultiplier))
                                }
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(selectedBackdrop.primaryTextColor)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedBackdrop.panelBackgroundColor)
                                .border(selectedBackdrop.borderColor, width: 1)
                            }
                        }
                        .padding(.horizontal, 8)
                        
                        // Media Buttons
                        HStack(spacing: 40) {
                            Button(action: {
                                syncService.skipBackward()
                                resetAutoHideTimer()
                            }) {
                                Image(systemName: "gobackward.10")
                                    .font(.system(size: 22, weight: .light))
                                    .foregroundColor(selectedBackdrop.primaryTextColor)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Button(action: {
                                if syncService.isPlaying {
                                    syncService.pause()
                                } else {
                                    syncService.play()
                                }
                                resetAutoHideTimer()
                            }) {
                                Image(systemName: syncService.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(selectedBackdrop.primaryTextColor)
                                    .frame(width: 72, height: 72)
                                    .background(selectedBackdrop.panelBackgroundColor)
                                    .border(selectedBackdrop.borderColor, width: 1)
                            }
                            .buttonStyle(MetroTileButtonStyle())
                            
                            Button(action: {
                                syncService.skipForward()
                                resetAutoHideTimer()
                            }) {
                                Image(systemName: "goforward.10")
                                    .font(.system(size: 22, weight: .light))
                                    .foregroundColor(selectedBackdrop.primaryTextColor)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        // Options and Chapters Toggles
                        HStack(spacing: 40) {
                            Spacer()
                            
                            Button(action: {
                                withAnimation(.metroTransition) {
                                    showChapters.toggle()
                                    showSettings = false
                                }
                                resetAutoHideTimer()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "list.bullet")
                                    Text("CHAPTERS")
                                }
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1)
                                .foregroundColor(selectedBackdrop.secondaryTextColor)
                            }
                            
                            Button(action: {
                                withAnimation(.metroTransition) {
                                    showSettings.toggle()
                                    showChapters = false
                                }
                                resetAutoHideTimer()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "textformat.size")
                                    Text("DISPLAY OPTIONS")
                                }
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1)
                                .foregroundColor(selectedBackdrop.secondaryTextColor)
                            }
                            
                            Spacer()
                        }
                        .padding(.top, 4)
                    }
                    .padding(24)
                    .background(selectedBackdrop.panelBackgroundColor)
                    .border(selectedBackdrop.borderColor, width: 1)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 34)
                }
                .ignoresSafeArea()
                .transition(.move(edge: .bottom))
            }
            
            // Custom Settings Overlay Sheet
            if showSettings {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.metroTransition) {
                                showSettings = false
                            }
                            resetAutoHideTimer()
                        }
                    
                    VStack {
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 24) {
                            HStack {
                                Text("DISPLAY SETTINGS")
                                    .font(.system(size: 12, weight: .bold))
                                    .tracking(2)
                                    .foregroundColor(selectedBackdrop.secondaryTextColor)
                                Spacer()
                                Button(action: {
                                    withAnimation(.metroTransition) {
                                        showSettings = false
                                    }
                                    resetAutoHideTimer()
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.footnote)
                                        .foregroundColor(selectedBackdrop.primaryTextColor)
                                        .padding(8)
                                        .background(selectedBackdrop.panelBackgroundColor)
                                }
                            }
                            .padding(.bottom, 8)
                            
                            // Backdrop Selection ( Midnight, Charcoal, Slate )
                            VStack(alignment: .leading, spacing: 10) {
                                Text("BACKDROP")
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(1)
                                    .foregroundColor(selectedBackdrop.secondaryTextColor)
                                
                                HStack(spacing: 12) {
                                    ForEach(ReaderBackdrop.allCases) { backdrop in
                                        Button(action: {
                                            selectedBackdrop = backdrop
                                            savePreferences()
                                            resetAutoHideTimer()
                                        }) {
                                            Text(backdrop.rawValue.uppercased())
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(selectedBackdrop == backdrop ? selectedBackdrop.primaryTextColor : selectedBackdrop.secondaryTextColor)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 12)
                                                .background(selectedBackdrop == backdrop ? selectedBackdrop.borderColor : Color.clear)
                                                .border(selectedBackdrop == backdrop ? selectedBackdrop.primaryTextColor : selectedBackdrop.borderColor, width: 1)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                            
                            // Font Selection
                            VStack(alignment: .leading, spacing: 10) {
                                Text("TYPEFACE")
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(1)
                                    .foregroundColor(selectedBackdrop.secondaryTextColor)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(ReadingFont.allCases) { rFont in
                                            Button(action: {
                                                selectedFont = rFont
                                                savePreferences()
                                                resetAutoHideTimer()
                                            }) {
                                                Text(rFont.rawValue)
                                                    .font(.system(size: 13, weight: .bold))
                                                    .foregroundColor(selectedFont == rFont ? selectedBackdrop.primaryTextColor : selectedBackdrop.secondaryTextColor)
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 12)
                                                    .background(selectedFont == rFont ? selectedBackdrop.borderColor : Color.clear)
                                                    .border(selectedFont == rFont ? selectedBackdrop.primaryTextColor : selectedBackdrop.borderColor, width: 1)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                }
                            }
                            
                            // Font Size Slider
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("SIZE")
                                        .font(.system(size: 10, weight: .bold))
                                        .tracking(1)
                                        .foregroundColor(selectedBackdrop.secondaryTextColor)
                                    Spacer()
                                    Text("\(Int(fontSize))pt")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(selectedBackdrop.primaryTextColor)
                                }
                                
                                Slider(value: $fontSize, in: 16...36, step: 2) { _ in
                                    savePreferences()
                                    resetAutoHideTimer()
                                }
                                .accentColor(selectedBackdrop.primaryTextColor)
                            }
                            
                            // Line Spacing Slider
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("LINE HEIGHT")
                                        .font(.system(size: 10, weight: .bold))
                                        .tracking(1)
                                        .foregroundColor(selectedBackdrop.secondaryTextColor)
                                    Spacer()
                                    Text("\(Int(lineSpacing))pt")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(selectedBackdrop.primaryTextColor)
                                }
                                
                                Slider(value: $lineSpacing, in: 4...16, step: 2) { _ in
                                    savePreferences()
                                    resetAutoHideTimer()
                                }
                                .accentColor(selectedBackdrop.primaryTextColor)
                            }
                            
                            // Margins
                            VStack(alignment: .leading, spacing: 10) {
                                Text("MARGINS")
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(1)
                                    .foregroundColor(selectedBackdrop.secondaryTextColor)
                                
                                HStack(spacing: 12) {
                                    ForEach([16, 24, 32, 48], id: \.self) { margin in
                                        Button(action: {
                                            marginSize = CGFloat(margin)
                                            savePreferences()
                                            resetAutoHideTimer()
                                        }) {
                                            Text("\(margin)px")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(marginSize == CGFloat(margin) ? selectedBackdrop.primaryTextColor : selectedBackdrop.secondaryTextColor)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 10)
                                                .background(marginSize == CGFloat(margin) ? selectedBackdrop.borderColor : Color.clear)
                                                .border(marginSize == CGFloat(margin) ? selectedBackdrop.primaryTextColor : selectedBackdrop.borderColor, width: 1)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                            
                            // Alignment Options
                            VStack(alignment: .leading, spacing: 10) {
                                Text("ALIGNMENT")
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(1)
                                    .foregroundColor(selectedBackdrop.secondaryTextColor)
                                
                                HStack(spacing: 12) {
                                    ForEach(ReadingAlignment.allCases) { align in
                                        Button(action: {
                                            selectedAlignment = align
                                            savePreferences()
                                            resetAutoHideTimer()
                                        }) {
                                            Text(align.rawValue.uppercased())
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(selectedAlignment == align ? selectedBackdrop.primaryTextColor : selectedBackdrop.secondaryTextColor)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 10)
                                                .background(selectedAlignment == align ? selectedBackdrop.borderColor : Color.clear)
                                                .border(selectedAlignment == align ? selectedBackdrop.primaryTextColor : selectedBackdrop.borderColor, width: 1)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                            
                            // Tracking / Letter Spacing Options
                            VStack(alignment: .leading, spacing: 10) {
                                Text("LETTER SPACING")
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(1)
                                    .foregroundColor(selectedBackdrop.secondaryTextColor)
                                
                                HStack(spacing: 8) {
                                    ForEach(ReadingTracking.allCases) { track in
                                        Button(action: {
                                            selectedTracking = track
                                            savePreferences()
                                            resetAutoHideTimer()
                                        }) {
                                            Text(track.rawValue.uppercased())
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(selectedTracking == track ? selectedBackdrop.primaryTextColor : selectedBackdrop.secondaryTextColor)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 10)
                                                .background(selectedTracking == track ? selectedBackdrop.borderColor : Color.clear)
                                                .border(selectedTracking == track ? selectedBackdrop.primaryTextColor : selectedBackdrop.borderColor, width: 1)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                        }
                        .padding(24)
                        .background(selectedBackdrop.panelBackgroundColor)
                        .border(selectedBackdrop.borderColor, width: 1)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 40)
                    }
                }
                .transition(.move(edge: .bottom))
            }
            
            // Custom Chapters Overlay Sheet
            if showChapters {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.metroTransition) {
                                showChapters = false
                            }
                            resetAutoHideTimer()
                        }
                    
                    VStack {
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 24) {
                            HStack {
                                Text("CHAPTERS")
                                    .font(.system(size: 12, weight: .bold))
                                    .tracking(2)
                                    .foregroundColor(selectedBackdrop.secondaryTextColor)
                                Spacer()
                                Button(action: {
                                    withAnimation(.metroTransition) {
                                        showChapters = false
                                    }
                                    resetAutoHideTimer()
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.footnote)
                                        .foregroundColor(selectedBackdrop.primaryTextColor)
                                        .padding(8)
                                        .background(selectedBackdrop.panelBackgroundColor)
                                }
                            }
                            .padding(.bottom, 8)
                            
                            // Scroll list of chapter links
                            ScrollView {
                                VStack(alignment: .leading, spacing: 16) {
                                    ForEach(syncService.chapters) { chapter in
                                        Button(action: {
                                            withAnimation(.metroFocus) {
                                                syncService.jumpToSentence(index: chapter.sentenceIndex)
                                                showChapters = false
                                            }
                                            resetAutoHideTimer()
                                        }) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(chapter.title)
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundColor(syncService.currentSentenceIndex >= chapter.sentenceIndex ? selectedBackdrop.primaryTextColor : selectedBackdrop.secondaryTextColor)
                                                    .multilineTextAlignment(.leading)
                                                
                                                Text("Index \(chapter.sentenceIndex + 1)")
                                                    .font(.system(size: 11, weight: .semibold))
                                                    .foregroundColor(selectedBackdrop.secondaryTextColor.opacity(0.8))
                                            }
                                            .padding(.vertical, 8)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        
                                        Divider()
                                            .background(selectedBackdrop.borderColor)
                                    }
                                }
                            }
                            .frame(maxHeight: 300)
                        }
                        .padding(24)
                        .background(selectedBackdrop.panelBackgroundColor)
                        .border(selectedBackdrop.borderColor, width: 1)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 40)
                    }
                }
                .transition(.move(edge: .bottom))
            }
            
            // Persistent Minimalist Progress Bar at the bottom
            VStack {
                Spacer()
                
                let progressPct: CGFloat = syncService.sentences.isEmpty ? 0 : CGFloat(syncService.currentSentenceIndex) / CGFloat(syncService.sentences.count)
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(selectedBackdrop.borderColor.opacity(0.3))
                            .frame(height: 3)
                        Rectangle()
                            .fill(selectedBackdrop.primaryTextColor)
                            .frame(width: geo.size.width * progressPct, height: 3)
                    }
                }
                .frame(height: 3)
            }
            .ignoresSafeArea(.all, edges: .bottom)
        }
        .navigationBarHidden(true)
        .onDisappear {
            autoHideTimer?.invalidate()
            syncService.stop()
        }
    }
    
    // Auto-hide controls timer management
    private func resetAutoHideTimer() {
        autoHideTimer?.invalidate()
        if isFocusMode {
            controlsVisible = false
            return
        }
        controlsVisible = true
        autoHideTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            withAnimation(.metroFocus) {
                if syncService.isPlaying {
                    controlsVisible = false
                }
            }
        }
    }
    
    private func getRemainingTimeText() -> String {
        let currentIdx = syncService.currentSentenceIndex
        let totalSentences = syncService.sentences.count
        guard totalSentences > 0 else { return "0% READ • 0 MIN LEFT" }
        
        var remainingWords = 0
        for i in currentIdx..<totalSentences {
            let words = syncService.sentences[i].split { $0.isWhitespace }
            remainingWords += words.count
        }
        
        let wpm = 200.0 * syncService.speedMultiplier
        let minutesLeft = Double(remainingWords) / wpm
        let mins = Int(ceil(minutesLeft))
        
        let progressPct = Int(Double(currentIdx) / Double(totalSentences) * 100.0)
        
        if mins < 1 {
            return "\(progressPct)% READ • LESS THAN A MIN LEFT"
        } else {
            return "\(progressPct)% READ • \(mins) MIN LEFT"
        }
    }
    
    // Save/Load preferences
    private func savePreferences() {
        UserDefaults.standard.set(fontSize, forKey: "aether_font_size")
        UserDefaults.standard.set(lineSpacing, forKey: "aether_line_spacing")
        UserDefaults.standard.set(marginSize, forKey: "aether_margin_size")
        UserDefaults.standard.set(selectedFont.rawValue, forKey: "aether_selected_font")
        UserDefaults.standard.set(selectedBackdrop.rawValue, forKey: "aether_selected_backdrop")
        UserDefaults.standard.set(selectedAlignment.rawValue, forKey: "aether_selected_alignment")
        UserDefaults.standard.set(selectedTracking.rawValue, forKey: "aether_selected_tracking")
    }
    
    private func loadPreferences() {
        if let size = UserDefaults.standard.value(forKey: "aether_font_size") as? CGFloat {
            fontSize = size
        } else if let oldSize = UserDefaults.standard.value(forKey: "etp_font_size") as? CGFloat {
            fontSize = oldSize
        }
        
        if let spacing = UserDefaults.standard.value(forKey: "aether_line_spacing") as? CGFloat {
            lineSpacing = spacing
        } else if let oldSpacing = UserDefaults.standard.value(forKey: "etp_line_spacing") as? CGFloat {
            lineSpacing = oldSpacing
        }
        
        if let margin = UserDefaults.standard.value(forKey: "aether_margin_size") as? CGFloat {
            marginSize = margin
        } else if let oldMargin = UserDefaults.standard.value(forKey: "etp_margin_size") as? CGFloat {
            marginSize = oldMargin
        }
        
        if let rawFont = UserDefaults.standard.string(forKey: "aether_selected_font"),
           let rFont = ReadingFont(rawValue: rawFont) {
            selectedFont = rFont
        } else if let oldRawFont = UserDefaults.standard.string(forKey: "etp_selected_font"),
                  let oldFont = ReadingFont(rawValue: oldRawFont) {
            selectedFont = oldFont
        }
        
        if let rawBackdrop = UserDefaults.standard.string(forKey: "aether_selected_backdrop"),
           let backdrop = ReaderBackdrop(rawValue: rawBackdrop) {
            selectedBackdrop = backdrop
        }
        
        if let rawAlignment = UserDefaults.standard.string(forKey: "aether_selected_alignment"),
           let alignment = ReadingAlignment(rawValue: rawAlignment) {
            selectedAlignment = alignment
        }
        
        if let rawTracking = UserDefaults.standard.string(forKey: "aether_selected_tracking"),
           let tracking = ReadingTracking(rawValue: rawTracking) {
            selectedTracking = tracking
        }
    }
    
    // Load Voice Settings Profile
    private func loadVoiceProfile() {
        let descriptor = FetchDescriptor<VoiceProfile>()
        if let profiles = try? modelContext.fetch(descriptor), let profile = profiles.first {
            syncService.speedMultiplier = profile.speedMultiplier
            syncService.pitchMultiplier = profile.pitchMultiplier
            if !profile.voiceIdentifier.isEmpty {
                syncService.selectedVoice = AVSpeechSynthesisVoice(identifier: profile.voiceIdentifier)
            }
        }
    }
    
    private func saveVoiceProfile() {
        let descriptor = FetchDescriptor<VoiceProfile>()
        let profiles = (try? modelContext.fetch(descriptor)) ?? []
        let profile = profiles.first ?? VoiceProfile()
        
        profile.speedMultiplier = syncService.speedMultiplier
        profile.pitchMultiplier = syncService.pitchMultiplier
        if let voice = syncService.selectedVoice {
            profile.voiceIdentifier = voice.identifier
            profile.language = voice.language
        }
        
        if profiles.isEmpty {
            modelContext.insert(profile)
        }
        try? modelContext.save()
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
    var backdrop: ReaderBackdrop
    var alignment: ReadingAlignment
    var tracking: ReadingTracking
    
    private func frameAlignment(for alignment: ReadingAlignment) -> Alignment {
        switch alignment {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
    
    var body: some View {
        Group {
            if isActive && isPlaying {
                Text(highlightActiveSentence(text: text, range: currentWordRange))
                    .font(font.font(size: fontSize))
                    .lineSpacing(lineSpacing)
                    .tracking(tracking.value)
                    .foregroundColor(backdrop.primaryTextColor)
                    .multilineTextAlignment(alignment.multilineAlignment)
                    .frame(maxWidth: .infinity, alignment: frameAlignment(for: alignment))
            } else {
                Text(text)
                    .font(font.font(size: fontSize))
                    .lineSpacing(lineSpacing)
                    .tracking(tracking.value)
                    .foregroundColor(isPlaying ? backdrop.secondaryTextColor : backdrop.primaryTextColor)
                    .multilineTextAlignment(alignment.multilineAlignment)
                    .frame(maxWidth: .infinity, alignment: frameAlignment(for: alignment))
                    .opacity(isPlaying ? 0.45 : 1.0)
            }
        }
        .animation(.metroFocus, value: isPlaying)
        .animation(.metroFocus, value: isActive)
    }
    
    private func highlightActiveSentence(text: String, range: NSRange?) -> AttributedString {
        var attrStr = AttributedString(text)
        
        // Use secondary text color as base for active sentence under light/dark
        attrStr.foregroundColor = backdrop.secondaryTextColor
        
        guard let range = range,
              let wordRange = text.rangeFromNSRange(range),
              let attrRange = attrStr.range(of: text[wordRange]) else {
            return attrStr
        }
        
        // Highlight active word in active color
        attrStr[attrRange].foregroundColor = backdrop.activeWordHighlightColor
        attrStr[attrRange].font = font.font(size: fontSize).bold()
        
        return attrStr
    }
}
