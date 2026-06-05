import SwiftUI
import SwiftData

public struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Document.dateImported, order: .reverse) private var allDocuments: [Document]
    
    @State private var isFileImporterPresented = false
    @State private var isImporting = false
    @State private var importError: String? = nil
    @State private var newlyImportedDoc: Document? = nil
    
    @State private var isVoiceCenterPresented = false
    @State private var navigationPath = NavigationPath()
    
    public init() {}
    
    private var recentDocument: Document? {
        allDocuments
            .filter { $0.dateLastRead != nil }
            .sorted { ($0.dateLastRead ?? Date.distantPast) > ($1.dateLastRead ?? Date.distantPast) }
            .first ?? allDocuments.first
    }
    
    private var recentImports: [Document] {
        Array(allDocuments.prefix(4))
    }
    
    private var favoriteDocuments: [Document] {
        allDocuments.filter { $0.isFavorite }
    }
    
    public var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Color.metroBlack
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 48) {
                        
                        // Header block - Oversized Metro Typography
                        VStack(alignment: .leading, spacing: 4) {
                            Text("AETHER")
                                .font(.system(size: 64, weight: .black, design: .default))
                                .foregroundColor(.metroWhite)
                                .tracking(-2)
                                .padding(.leading, -4)
                            
                            Text("IMMERSIVE FOCUS READER")
                                .font(.system(size: 11, weight: .light, design: .default))
                                .foregroundColor(.metroLightGray)
                                .tracking(5)
                        }
                        .padding(.top, 40)
                        .padding(.horizontal, 24)
                        
                        // 1. Continue Reading (Hero Section)
                        if let recent = recentDocument {
                            VStack(alignment: .leading, spacing: 16) {
                                SectionHeader(title: "CONTINUE READING")
                                
                                Button(action: {
                                    navigationPath.append(recent)
                                }) {
                                    VStack(alignment: .leading, spacing: 20) {
                                        HStack {
                                            Text(recent.fileType.uppercased())
                                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                .foregroundColor(.metroBlack)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.metroWhite)
                                            
                                            Spacer()
                                            
                                            if let lastRead = recent.dateLastRead {
                                                Text(formatLastRead(lastRead))
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundColor(.metroLightGray)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(recent.title)
                                                .font(.system(size: 24, weight: .bold))
                                                .foregroundColor(.metroWhite)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)
                                            
                                            Text(recent.author)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.metroLightGray)
                                                .lineLimit(1)
                                        }
                                        
                                        // Progress indicator
                                        if let progress = recent.readingProgress, !recent.rawText.isEmpty {
                                            let sentences = recent.rawText.components(separatedBy: ".").count
                                            let totalSentences = max(1, sentences)
                                            let pct = Double(progress.currentSentenceIndex) / Double(totalSentences)
                                            let progressPct = min(1.0, max(0.0, pct))
                                            
                                            VStack(spacing: 8) {
                                                HStack {
                                                    Text("\(Int(progressPct * 100))% completed")
                                                        .font(.system(size: 11, weight: .semibold))
                                                        .foregroundColor(.metroLightGray)
                                                    Spacer()
                                                    Text(formatRemainingTime(recent))
                                                        .font(.system(size: 11, weight: .semibold))
                                                        .foregroundColor(.metroLightGray)
                                                }
                                                
                                                GeometryReader { geo in
                                                    ZStack(alignment: .leading) {
                                                        Rectangle()
                                                            .fill(Color.metroGray)
                                                            .frame(height: 2)
                                                        Rectangle()
                                                            .fill(Color.metroWhite)
                                                            .frame(width: geo.size.width * CGFloat(progressPct), height: 2)
                                                    }
                                                }
                                                .frame(height: 2)
                                            }
                                        }
                                    }
                                    .padding(28)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 220)
                                    .background(Color.metroCharcoal)
                                    .border(Color.metroGray, width: 1)
                                }
                                .buttonStyle(MetroTileButtonStyle())
                            }
                            .padding(.horizontal, 24)
                        }
                        
                        // 2. Recent Imports (Horizontal Scroll Row)
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                SectionHeader(title: "RECENT IMPORTS")
                                Spacer()
                                Button(action: {
                                    isFileImporterPresented = true
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus")
                                        Text("IMPORT")
                                    }
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.metroWhite)
                                }
                            }
                            .padding(.horizontal, 24)
                            
                            if recentImports.isEmpty {
                                Button(action: { isFileImporterPresented = true }) {
                                    VStack(spacing: 12) {
                                        Image(systemName: "arrow.down.doc")
                                            .font(.system(size: 28, weight: .ultraLight))
                                            .foregroundColor(.metroLightGray)
                                        Text("Import your first document")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.metroWhite)
                                        Text("PDF, EPUB, TXT, DOCX, MD, RTF")
                                            .font(.system(size: 11))
                                            .foregroundColor(.metroLightGray)
                                    }
                                    .padding(32)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.metroCharcoal)
                                    .border(Color.metroGray, width: 1)
                                    .padding(.horizontal, 24)
                                }
                                .buttonStyle(MetroTileButtonStyle())
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(recentImports) { doc in
                                            Button(action: {
                                                navigationPath.append(doc)
                                            }) {
                                                VStack(alignment: .leading, spacing: 12) {
                                                    // File Type Badge
                                                    Text(doc.fileType.uppercased())
                                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                                        .foregroundColor(.metroLightGray)
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .border(Color.metroGray, width: 1)
                                                    
                                                    Spacer()
                                                    
                                                    Text(doc.title)
                                                        .font(.system(size: 16, weight: .bold))
                                                        .foregroundColor(.metroWhite)
                                                        .lineLimit(2)
                                                        .multilineTextAlignment(.leading)
                                                    
                                                    Text(doc.author)
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.metroLightGray)
                                                        .lineLimit(1)
                                                }
                                                .padding(20)
                                                .frame(width: 160, height: 160, alignment: .leading)
                                                .background(Color.metroCharcoal)
                                                .border(Color.metroGray, width: 1)
                                            }
                                            .buttonStyle(MetroTileButtonStyle())
                                        }
                                    }
                                    .padding(.horizontal, 24)
                                }
                            }
                        }
                        
                        // 3. Grid Row: Library (Square) & Voice settings (Square)
                        HStack(spacing: 16) {
                            // Library Link Card
                            Button(action: {
                                navigationPath.append("library")
                            }) {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("LIBRARY")
                                            .font(.system(size: 11, weight: .bold))
                                            .tracking(2)
                                            .foregroundColor(.metroSilver)
                                        Spacer()
                                        Image(systemName: "books.vertical")
                                            .font(.headline)
                                            .foregroundColor(.metroLightGray)
                                    }
                                    
                                    Spacer()
                                    
                                    Text("\(allDocuments.count)")
                                        .font(.system(size: 48, weight: .bold))
                                        .foregroundColor(.metroWhite)
                                    
                                    Text(allDocuments.count == 1 ? "document" : "documents")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.metroLightGray)
                                }
                                .padding(24)
                                .frame(maxWidth: .infinity)
                                .frame(height: 170)
                                .background(Color.metroCharcoal)
                                .border(Color.metroGray, width: 1)
                            }
                            .buttonStyle(MetroTileButtonStyle())
                            
                            // Voice Settings Card
                            Button(action: {
                                isVoiceCenterPresented = true
                            }) {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("VOICE")
                                            .font(.system(size: 11, weight: .bold))
                                            .tracking(2)
                                            .foregroundColor(.metroSilver)
                                        Spacer()
                                        Image(systemName: "person.wave.2")
                                            .font(.headline)
                                            .foregroundColor(.metroLightGray)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "slider.horizontal.3")
                                        .font(.system(size: 32, weight: .light))
                                        .foregroundColor(.metroWhite)
                                    
                                    Text("Voice Center")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.metroLightGray)
                                }
                                .padding(24)
                                .frame(maxWidth: .infinity)
                                .frame(height: 170)
                                .background(Color.metroCharcoal)
                                .border(Color.metroGray, width: 1)
                            }
                            .buttonStyle(MetroTileButtonStyle())
                        }
                        .padding(.horizontal, 24)
                        
                        // 4. Favorites (If not empty)
                        if !favoriteDocuments.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    SectionHeader(title: "FAVORITES")
                                    Spacer()
                                    Button(action: {
                                        navigationPath.append("favorites")
                                    }) {
                                        Text("VIEW ALL")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.metroWhite)
                                    }
                                }
                                
                                ForEach(favoriteDocuments.prefix(3)) { doc in
                                    Button(action: {
                                        navigationPath.append(doc)
                                    }) {
                                        HStack(spacing: 16) {
                                            Image(systemName: "star.fill")
                                                .foregroundColor(.metroWhite)
                                                .font(.caption)
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(doc.title)
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundColor(.metroWhite)
                                                    .lineLimit(1)
                                                    .multilineTextAlignment(.leading)
                                                Text(doc.author)
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.metroLightGray)
                                                    .lineLimit(1)
                                            }
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.footnote)
                                                .foregroundColor(.metroLightGray)
                                        }
                                        .padding(20)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.metroCharcoal)
                                        .border(Color.metroGray, width: 1)
                                    }
                                    .buttonStyle(MetroTileButtonStyle())
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                        
                        // Import Status / Error Panel
                        if let error = importError {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Import Failed")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                Text(error)
                                    .font(.system(size: 12))
                                    .foregroundColor(.metroLightGray)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.metroCharcoal)
                            .border(Color.red.opacity(0.5), width: 1)
                            .padding(.horizontal, 24)
                            .onAppear {
                                Task {
                                    try? await Task.sleep(nanoseconds: 6_000_000_000)
                                    self.importError = nil
                                }
                            }
                        }
                    }
                    .padding(.bottom, 60)
                }
            }
            .navigationBarHidden(true)
            .fileImporter(
                isPresented: $isFileImporterPresented,
                allowedContentTypes: ImportService.allowedContentTypes,
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    isImporting = true
                    importError = nil
                    Task {
                        do {
                            let doc = try await ImportService.importFile(from: url, into: modelContext)
                            await MainActor.run {
                                self.isImporting = false
                                self.newlyImportedDoc = doc
                                self.navigationPath.append(doc)
                            }
                        } catch {
                            await MainActor.run {
                                self.isImporting = false
                                self.importError = error.localizedDescription
                            }
                        }
                    }
                case .failure(let error):
                    self.importError = error.localizedDescription
                }
            }
            .sheet(isPresented: $isVoiceCenterPresented) {
                VoiceCenterView()
            }
            .navigationDestination(for: String.self) { val in
                if val == "library" {
                    LibraryView(filterFavorites: false, navigationPath: $navigationPath)
                } else if val == "favorites" {
                    LibraryView(filterFavorites: true, navigationPath: $navigationPath)
                }
            }
            .navigationDestination(for: Document.self) { doc in
                ReaderView(document: doc)
            }
        }
    }
    
    // Helpers
    private func formatLastRead(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Last read: " + formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func formatRemainingTime(_ doc: Document) -> String {
        guard let progress = doc.readingProgress, !doc.rawText.isEmpty else {
            return "Estimated time: " + formatDuration(doc.durationSeconds)
        }
        let sentences = doc.rawText.components(separatedBy: ".").count
        let totalSentences = max(1, sentences)
        let pctLeft = 1.0 - (Double(progress.currentSentenceIndex) / Double(totalSentences))
        let remainingSeconds = max(0.0, doc.durationSeconds * pctLeft)
        return formatDuration(remainingSeconds) + " left"
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(ceil(seconds / 60.0))
        if mins < 1 {
            return "1 min"
        } else if mins < 60 {
            return "\(mins) min"
        } else {
            let hrs = mins / 60
            let remMins = mins % 60
            if remMins == 0 {
                return "\(hrs) hr"
            } else {
                return "\(hrs) hr \(remMins) min"
            }
        }
    }
}

// MARK: - Section Header Helper
struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .tracking(3)
            .foregroundColor(.metroSilver)
    }
}
