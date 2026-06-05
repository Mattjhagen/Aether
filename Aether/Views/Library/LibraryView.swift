import SwiftUI
import SwiftData

public struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \Document.dateImported, order: .reverse) private var allDocuments: [Document]
    
    public var filterFavorites: Bool
    @Binding public var navigationPath: NavigationPath
    
    public init(filterFavorites: Bool, navigationPath: Binding<NavigationPath>) {
        self.filterFavorites = filterFavorites
        self._navigationPath = navigationPath
    }
    
    private var displayedDocuments: [Document] {
        if filterFavorites {
            return allDocuments.filter { $0.isFavorite }
        } else {
            return allDocuments
        }
    }
    
    public var body: some View {
        ZStack {
            Color.metroBlack
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 0) {
                
                // Custom Navigation Bar - Metro Style (Oversized title, custom back button)
                HStack(alignment: .top, spacing: 16) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.metroWhite)
                            .padding(.top, 12)
                    }
                    
                    VStack(alignment: .leading, spacing: 0) {
                        Text(filterFavorites ? "COLLECTION" : "ALL")
                            .font(.system(size: 12, weight: .light))
                            .tracking(4)
                            .foregroundColor(.metroLightGray)
                            .textCase(.uppercase)
                        
                        Text(filterFavorites ? "FAVORITES" : "LIBRARY")
                            .font(.system(size: 44, weight: .black))
                            .foregroundColor(.metroWhite)
                            .tracking(-1)
                            .padding(.leading, -2)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 32)
                
                // Document list / cards
                if displayedDocuments.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: filterFavorites ? "star.slash" : "doc.text.magnifyingglass")
                            .font(.system(size: 40, weight: .ultraLight))
                            .foregroundColor(.metroLightGray)
                        
                        Text(filterFavorites ? "No starred items" : "Library is empty")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.metroWhite)
                        
                        Text(filterFavorites ? "Star your favorite documents to access them quickly here." : "Import documents on the dashboard to get started.")
                            .font(.system(size: 14))
                            .foregroundColor(.metroLightGray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            ForEach(displayedDocuments) { doc in
                                LibraryDocumentCard(
                                    doc: doc,
                                    onSelect: {
                                        navigationPath.append(doc)
                                    },
                                    onToggleFavorite: {
                                        doc.isFavorite.toggle()
                                        try? modelContext.save()
                                    },
                                    onDelete: {
                                        deleteDocument(doc)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .navigationBarHidden(true)
    }
    
    private func deleteDocument(_ document: Document) {
        withAnimation(.metroTransition) {
            modelContext.delete(document)
            try? modelContext.save()
        }
    }
}

// MARK: - Library Document Card Component
struct LibraryDocumentCard: View {
    var doc: Document
    var onSelect: () -> Void
    var onToggleFavorite: () -> Void
    var onDelete: () -> Void
    
    private var progressPct: Double {
        guard let progress = doc.readingProgress, !doc.rawText.isEmpty else { return 0.0 }
        let sentences = doc.rawText.components(separatedBy: ".").count
        let totalSentences = max(1, sentences)
        return min(1.0, max(0.0, Double(progress.currentSentenceIndex) / Double(totalSentences)))
    }
    
    var body: some View {
        HStack(spacing: 20) {
            // Typography Cover Tile
            Button(action: onSelect) {
                ZStack {
                    Color.metroGray
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text(doc.fileType.uppercased())
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundColor(.metroLightGray)
                            Spacer()
                        }
                        
                        Spacer()
                        
                        Text(String(doc.title.prefix(1)).uppercased())
                            .font(.system(size: 40, weight: .black))
                            .foregroundColor(.metroWhite)
                        
                        Spacer()
                    }
                    .padding(14)
                }
                .frame(width: 90, height: 120)
                .border(Color.metroLightGray.opacity(0.3), width: 1)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Details
            VStack(alignment: .leading, spacing: 6) {
                Button(action: onSelect) {
                    VStack(alignment: .leading, spacing: 2) {
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
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                // Reading progress text and bar
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(Int(progressPct * 100))% read")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.metroLightGray)
                        
                        Spacer()
                        
                        Text(formatRemainingTime(doc))
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
                
                // Last Opened Date
                if let lastRead = doc.dateLastRead {
                    Text(formatLastRead(lastRead))
                        .font(.system(size: 10))
                        .foregroundColor(.metroLightGray)
                }
            }
            .frame(height: 120)
            
            Spacer()
            
            // Actions Column
            VStack(spacing: 16) {
                Button(action: onToggleFavorite) {
                    Image(systemName: doc.isFavorite ? "star.fill" : "star")
                        .font(.system(size: 16))
                        .foregroundColor(doc.isFavorite ? .metroWhite : .metroLightGray)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(.metroLightGray)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(16)
        .background(Color.metroCharcoal)
        .border(Color.metroGray, width: 1)
    }
    
    private func formatLastRead(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return "Opened " + formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func formatRemainingTime(_ doc: Document) -> String {
        let pctLeft = 1.0 - progressPct
        let remainingSeconds = max(0.0, doc.durationSeconds * pctLeft)
        return formatDuration(remainingSeconds) + " left"
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(ceil(seconds / 60.0))
        if mins < 1 {
            return "1m"
        } else if mins < 60 {
            return "\(mins)m"
        } else {
            let hrs = mins / 60
            let remMins = mins % 60
            if remMins == 0 {
                return "\(hrs)h"
            } else {
                return "\(hrs)h \(remMins)m"
            }
        }
    }
}
