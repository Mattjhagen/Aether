import SwiftUI
import SwiftData

public struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Document.dateImported, order: .reverse) private var allDocuments: [Document]
    
    @State private var isFileImporterPresented = false
    @State private var isImporting = false
    @State private var importError: String? = nil
    @State private var newlyImportedDoc: Document? = nil
    
    // Navigation path
    @State private var navigationPath = NavigationPath()
    
    public init() {}
    
    // Get the most recently read document
    private var recentDocument: Document? {
        allDocuments
            .filter { $0.dateLastRead != nil }
            .sorted { ($0.dateLastRead ?? Date.distantPast) > ($1.dateLastRead ?? Date.distantPast) }
            .first ?? allDocuments.first
    }
    
    private var favoriteDocuments: [Document] {
        allDocuments.filter { $0.isFavorite }
    }
    
    public var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Color.metroBlack
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 40) {
                        
                        // Header block - Oversized Metro Typography
                        VStack(alignment: .leading, spacing: 0) {
                            Text("ETP")
                                .font(.system(size: 20, weight: .light, design: .default))
                                .foregroundColor(.metroLightGray)
                                .tracking(6)
                                .textCase(.uppercase)
                            
                            Text("READER")
                                .font(.system(size: 64, weight: .black, design: .default))
                                .foregroundColor(.metroWhite)
                                .tracking(-2)
                                .padding(.leading, -4) // optical alignment
                        }
                        .padding(.top, 40)
                        .padding(.horizontal, 24)
                        
                        // Asymmetric Grid / Content Tiles
                        VStack(spacing: 16) {
                            
                            // Row 1: Continue Reading / Recent (Full width wide tile)
                            if let recent = recentDocument {
                                Button(action: {
                                    navigationPath.append(recent)
                                }) {
                                    VStack(alignment: .leading, spacing: 16) {
                                        HStack {
                                            Text("CONTINUE")
                                                .font(.system(size: 11, weight: .semibold))
                                                .tracking(3)
                                                .foregroundColor(.metroSilver)
                                            
                                            Spacer()
                                            
                                            Image(systemName: "arrow.right")
                                                .font(.footnote)
                                                .foregroundColor(.metroLightGray)
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
                                        
                                        // Simple Progress Bar
                                        if let progress = recent.readingProgress, !recent.rawText.isEmpty {
                                            let sentences = recent.rawText.components(separatedBy: CharacterSet.punctuationCharacters).count // approximation
                                            let totalSentences = max(1, sentences)
                                            let pct = Double(progress.currentSentenceIndex) / Double(totalSentences)
                                            
                                            ProgressView(value: min(1.0, max(0.0, pct)))
                                                .progressViewStyle(LinearProgressViewStyle(tint: .metroSilver))
                                                .background(Color.metroGray)
                                                .scaleEffect(x: 1, y: 0.5, anchor: .center)
                                        }
                                    }
                                    .padding(24)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 180)
                                    .background(Color.metroCharcoal)
                                    .border(Color.metroGray, width: 1)
                                }
                                .buttonStyle(MetroTileButtonStyle())
                            } else {
                                // No books state - guide tile
                                Button(action: {
                                    isFileImporterPresented = true
                                }) {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("WELCOME")
                                            .font(.system(size: 11, weight: .semibold))
                                            .tracking(3)
                                            .foregroundColor(.metroSilver)
                                        
                                        Spacer()
                                        
                                        Text("Tap to import a file")
                                            .font(.system(size: 22, weight: .bold))
                                            .foregroundColor(.metroWhite)
                                        
                                        Text("PDF, TXT, EPUB, DOCX, MD")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.metroLightGray)
                                    }
                                    .padding(24)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 180)
                                    .background(Color.metroCharcoal)
                                    .border(Color.metroGray, width: 1)
                                }
                                .buttonStyle(MetroTileButtonStyle())
                            }
                            
                            // Row 2: Asymmetric pair - Library (Square) & Import (Square)
                            HStack(spacing: 16) {
                                
                                // Library Tile
                                Button(action: {
                                    navigationPath.append("library")
                                }) {
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack {
                                            Text("LIBRARY")
                                                .font(.system(size: 11, weight: .semibold))
                                                .tracking(3)
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
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.metroLightGray)
                                    }
                                    .padding(20)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 160)
                                    .background(Color.metroCharcoal)
                                    .border(Color.metroGray, width: 1)
                                }
                                .buttonStyle(MetroTileButtonStyle())
                                
                                // Import Tile
                                Button(action: {
                                    isFileImporterPresented = true
                                }) {
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack {
                                            Text("IMPORT")
                                                .font(.system(size: 11, weight: .semibold))
                                                .tracking(3)
                                                .foregroundColor(.metroSilver)
                                            Spacer()
                                            Image(systemName: "plus")
                                                .font(.headline)
                                                .foregroundColor(.metroLightGray)
                                        }
                                        
                                        Spacer()
                                        
                                        if isImporting {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .metroWhite))
                                                .scaleEffect(1.2)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        } else {
                                            Image(systemName: "arrow.down.doc")
                                                .font(.system(size: 36, weight: .light))
                                                .foregroundColor(.metroWhite)
                                        }
                                        
                                        Text("Add content")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.metroLightGray)
                                    }
                                    .padding(20)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 160)
                                    .background(Color.metroCharcoal)
                                    .border(Color.metroGray, width: 1)
                                }
                                .buttonStyle(MetroTileButtonStyle())
                                .disabled(isImporting)
                            }
                            
                            // Row 3: Favorites Tile (Full width, or conditional)
                            if !favoriteDocuments.isEmpty {
                                Button(action: {
                                    navigationPath.append("favorites")
                                }) {
                                    VStack(alignment: .leading, spacing: 16) {
                                        HStack {
                                            Text("FAVORITES")
                                                .font(.system(size: 11, weight: .semibold))
                                                .tracking(3)
                                                .foregroundColor(.metroSilver)
                                            
                                            Spacer()
                                            
                                            Image(systemName: "star.fill")
                                                .font(.footnote)
                                                .foregroundColor(.metroWhite)
                                        }
                                        
                                        Spacer()
                                        
                                        HStack(spacing: 8) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("\(favoriteDocuments.count) Starred")
                                                    .font(.system(size: 20, weight: .bold))
                                                    .foregroundColor(.metroWhite)
                                                Text("Tap to view favorited items")
                                                    .font(.system(size: 13, weight: .medium))
                                                    .foregroundColor(.metroLightGray)
                                            }
                                            Spacer()
                                        }
                                    }
                                    .padding(20)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 120)
                                    .background(Color.metroCharcoal)
                                    .border(Color.metroGray, width: 1)
                                }
                                .buttonStyle(MetroTileButtonStyle())
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        // Status/Error Panel if any
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
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
            .fileImporter(
                isPresented: $isFileImporterPresented,
                allowedContentTypes: DocumentImporter.allowedContentTypes,
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    isImporting = true
                    importError = nil
                    Task {
                        do {
                            let doc = try await DocumentImporter.importFile(from: url, into: modelContext)
                            await MainActor.run {
                                self.isImporting = false
                                self.newlyImportedDoc = doc
                                // Navigate immediately to the imported book
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
            // Global Nav Destinations
            .navigationDestination(for: String.self) { val in
                if val == "library" {
                    LibraryView(filterFavorites: false, navigationPath: $navigationPath)
                } else if val == "favorites" {
                    LibraryView(filterFavorites: true, navigationPath: $navigationPath)
                }
            }
            .navigationDestination(for: Document.self) { doc in
                ReadingView(document: doc)
            }
        }
    }
}
