import Foundation
import CoreGraphics
#if canImport(Photos)
import Photos
#endif
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Asynchronous, memory-bounded thumbnail and preview loader for PhotoKit assets.
public final class PhotoThumbnailLoader: @unchecked Sendable {
    
    public static let shared = PhotoThumbnailLoader()
    
    private let cache = NSCache<NSString, PlatformImage>()
    
    public init() {
        cache.countLimit = 250 // Keep max 250 thumbnails in memory
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB memory ceiling
    }
    
    #if canImport(Photos)
    /// Loads a thumbnail image for a given PhotoKit local identifier.
    public func loadThumbnail(
        for localIdentifier: String,
        targetSize: CGSize = CGSize(width: 120, height: 120)
    ) async -> PlatformImage? {
        let cacheKey = "\(localIdentifier)_\(Int(targetSize.width))" as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }
        
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let asset = fetch.firstObject else { return nil }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true // allow cached iCloud thumbnail fetch
        
        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                if let image = image {
                    self.cache.setObject(image, forKey: cacheKey)
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    #endif
    
    /// Clears the memory cache (e.g. on low memory warning).
    public func clearCache() {
        cache.removeAllObjects()
    }
}
