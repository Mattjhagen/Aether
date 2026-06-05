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
                
                // Document List
                if displayedDocuments.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: filterFavorites ? "star.slash" : "doc.text.magnifyingglass")
                            .font(.system(size: 40, weight: .ultraLight))
                            .foregroundColor(.metroLightGray)
                        
                        Text(filterFavorites ? "No starred items" : "Library is empty")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.metroWhite)
                        
                        Text(filterFavorites ? "Star your favorite documents to access them quickly here." : "Import PDFs, EPUBs, or text files on the dashboard to get started.")
                            .font(.system(size: 14))
                            .foregroundColor(.metroLightGray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(displayedDocuments) { doc in
                                DocumentRow(doc: doc, onSelect: {
                                    navigationPath.append(doc)
                                }, onDelete: {
                                    deleteDocument(doc)
                                }, onToggleFavorite: {
                                    doc.isFavorite.toggle()
                                    try? modelContext.save()
                                })
                            }
                        }
                        .padding(.horizontal, 24)
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

// MARK: - Document Row Component
struct DocumentRow: View {
    var doc: Document
    var onSelect: () -> Void
    var onDelete: () -> Void
    var onToggleFavorite: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Extension Badge (e.g. PDF, TXT, EPUB)
                Text(doc.fileType.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.metroWhite)
                    .frame(width: 44, height: 44)
                    .background(Color.metroGray)
                    .border(Color.metroLightGray.opacity(0.3), width: 1)
                
                // Title & Author details
                Button(action: onSelect) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(doc.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.metroWhite)
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)
                        
                        Text(doc.author)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.metroLightGray)
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                // Favorite Button
                Button(action: onToggleFavorite) {
                    Image(systemName: doc.isFavorite ? "star.fill" : "star")
                        .font(.system(size: 16))
                        .foregroundColor(doc.isFavorite ? .metroWhite : .metroLightGray)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Delete Button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(.metroLightGray)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.vertical, 16)
            
            Divider()
                .background(Color.metroGray)
        }
    }
}
