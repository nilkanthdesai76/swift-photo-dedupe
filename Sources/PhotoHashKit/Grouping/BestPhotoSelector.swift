import Foundation

/// Heuristic engine to pick the optimal "Keeper" (Best Photo) in a duplicate/similar cluster.
/// Ensures the highest fidelity asset is protected while suggesting lower-quality copies for deletion.
public enum BestPhotoSelector {
    
    /// Evaluates a list of assets and returns the ID of the highest quality keeper.
    public static func pickBest(from assets: [AssetSnapshot]) -> String {
        guard let first = assets.first else { return "" }
        if assets.count == 1 { return first.id }
        
        let sorted = assets.sorted { a, b in
            // 1. Favorites always win
            if a.isFavorite != b.isFavorite {
                return a.isFavorite && !b.isFavorite
            }
            
            // 2. Highest resolution (pixel count)
            if a.totalPixels != b.totalPixels {
                return a.totalPixels > b.totalPixels
            }
            
            // 3. Higher file size (less compressed)
            if a.fileSize != b.fileSize {
                return a.fileSize > b.fileSize
            }
            
            // 4. Earliest capture date
            return a.creationDate < b.creationDate
        }
        
        return sorted.first?.id ?? first.id
    }
}
