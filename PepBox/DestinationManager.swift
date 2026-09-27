import Foundation
import SwiftUI
import Combine

struct Destination: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var path: String // Using path for simplicity; standard URL bookmark handling would be better for sandboxing but app seems to rely on file paths.
    
    var url: URL {
        URL(fileURLWithPath: path)
    }
}

class DestinationManager: ObservableObject {
    static let shared = DestinationManager()
    
    @Published var destinations: [Destination] = []
    
    // Max number of recent destinations to keep if we wanted a history, 
    // but the user seemingly wants "Favorites". We will treat them as saved favorites.
    
    private let key = "SavedDestinations"
    
    init() {
        loadDestinations()
    }
    
    func addDestination(url: URL) {
        let path = url.path
        // Avoid duplicates
        if !destinations.contains(where: { $0.path == path }) {
            let name = url.lastPathComponent
            let newDest = Destination(name: name, path: path)
            destinations.append(newDest)
            saveDestinations()
        }
    }
    
    func removeDestination(id: UUID) {
        destinations.removeAll { $0.id == id }
        saveDestinations()
    }
    
    private func saveDestinations() {
        if let encoded = try? JSONEncoder().encode(destinations) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
    
    private func loadDestinations() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Destination].self, from: data) {
            destinations = decoded
        }
    }
}
