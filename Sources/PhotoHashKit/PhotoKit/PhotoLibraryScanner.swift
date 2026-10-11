import Foundation
import CoreGraphics

#if canImport(Photos)
import Photos
#endif

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Thread-safe progress update emitted during background library scanning.
public struct ScanProgress: Sendable {
    public let processed: Int
    public let total: Int
    public let currentFilename: String
    public let thermalState: String
    public let currentGroupCount: Int
    
    public init(
        processed: Int,
        total: Int,
        currentFilename: String,
        thermalState: String,
        currentGroupCount: Int
    ) {
        self.processed = processed
        self.total = total
        self.currentFilename = currentFilename
        self.thermalState = thermalState
        self.currentGroupCount = currentGroupCount
    }
    
    public var processedCount: Int { processed }
    public var totalCount: Int { total }
    
    public var fractionCompleted: Double {
        total > 0 ? Double(processed) / Double(total) : 0
    }
}

/// Photo library scanner engineered specifically for zero thermal footprint and seamless iCloud thumbnail extraction.
public final class PhotoLibraryScanner: @unchecked Sendable {
    
    public init() {}
    
    #if canImport(Photos)
    /// Scans the user's system Photos library (including iCloud-offloaded photos) using low-res cached thumbnails.
    public func scanPhotoLibrary(
        includeSimilar: Bool = true,
        batchSize: Int = 40,
        onProgress: (@Sendable (ScanProgress) -> Void)? = nil
    ) async -> DedupeScanResult {
        let startTime = Date()
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let assetsFetch = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        let totalCount = assetsFetch.count
        
        guard totalCount > 0 else {
            return DedupeScanResult(
                scannedAt: Date(),
                durationSec: 0,
                totalScanned: 0,
                groups: [],
                peakThermalState: ThermalGovernor.shared.thermalStatusDescription
            )
        }
        
        var scannedSnapshots: [AssetSnapshot] = []
        scannedSnapshots.reserveCapacity(totalCount)
        
        let imageManager = PHImageManager.default()
        let thumbnailSize = CGSize(width: 64, height: 64)
        
        // Setup local thumbnail-only extraction options
        let localOptions = PHImageRequestOptions()
        localOptions.isSynchronous = true
        localOptions.deliveryMode = .fastFormat
        localOptions.resizeMode = .fast
        localOptions.isNetworkAccessAllowed = false // Never trigger full original download from iCloud!
        
        // Fallback for missing local cache: network-allowed but still strictly 64x64 thumbnail
        let cloudThumbnailOptions = PHImageRequestOptions()
        cloudThumbnailOptions.isSynchronous = true
        cloudThumbnailOptions.deliveryMode = .fastFormat
        cloudThumbnailOptions.resizeMode = .fast
        cloudThumbnailOptions.isNetworkAccessAllowed = true
        
        var processedCount = 0
        
        for startIndex in stride(from: 0, to: totalCount, by: batchSize) {
            let endIndex = min(startIndex + batchSize, totalCount)
            
            // Process chunk inside autoreleasepool to release bitmap memory instantly
            autoreleasepool {
                for i in startIndex..<endIndex {
                    let asset = assetsFetch.object(at: i)
                    let filename = asset.value(forKey: "filename") as? String ?? "Photo-\(asset.localIdentifier.prefix(8)).jpg"
                    let creationDate = asset.creationDate ?? Date()
                    let pixelWidth = asset.pixelWidth
                    let pixelHeight = asset.pixelHeight
                    let isFavorite = asset.isFavorite
                    
                    var cgThumb: CGImage?
                    var isLocallyCached = true
                    
                    // 1. Try local on-disk thumbnail cache first (zero network bandwidth, zero wait)
                    imageManager.requestImage(
                        for: asset,
                        targetSize: thumbnailSize,
                        contentMode: .aspectFill,
                        options: localOptions
                    ) { image, info in
                        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
                        if let nsImg = image {
                            cgThumb = nsImg.cgImage(forProposedRect: nil, context: nil, hints: nil)
                        }
                        #elseif canImport(UIKit)
                        if let uiImg = image {
                            cgThumb = uiImg.cgImage
                        }
                        #endif
                        
                        let isInCloud = info?[PHImageResultIsInCloudKey] as? Bool ?? false
                        if isInCloud || cgThumb == nil {
                            isLocallyCached = false
                        }
                    }
                    
                    // 2. If thumbnail wasn't in local disk cache, request strictly a 64x64 thumbnail
                    if cgThumb == nil {
                        imageManager.requestImage(
                            for: asset,
                            targetSize: thumbnailSize,
                            contentMode: .aspectFill,
                            options: cloudThumbnailOptions
                        ) { image, _ in
                            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
                            if let nsImg = image {
                                cgThumb = nsImg.cgImage(forProposedRect: nil, context: nil, hints: nil)
                            }
                            #elseif canImport(UIKit)
                            if let uiImg = image {
                                cgThumb = uiImg.cgImage
                            }
                            #endif
                        }
                    }
                    
                    // 3. Compute 16-byte DualHash
                    var dualHash: DualHash? = nil
                    if let cg = cgThumb {
                        dualHash = DualHash.compute(from: cg)
                    }
                    
                    // Approximate file size if resource values unavailable
                    let estimatedSize = Int64(pixelWidth * pixelHeight * 3 / 8) // ~JPEG estimate
                    
                    let snapshot = AssetSnapshot(
                        id: asset.localIdentifier,
                        filename: filename,
                        creationDate: creationDate,
                        pixelWidth: pixelWidth,
                        pixelHeight: pixelHeight,
                        fileSize: estimatedSize,
                        isFavorite: isFavorite,
                        isLocallyAvailable: isLocallyCached,
                        dualHash: dualHash
                    )
                    
                    scannedSnapshots.append(snapshot)
                    processedCount += 1
                }
            }
            
            // Thermal governor micro-pause to keep SoC completely cool
            await ThermalGovernor.shared.applyThermalPacing()
            
            let progress = ScanProgress(
                processed: processedCount,
                total: totalCount,
                currentFilename: scannedSnapshots.last?.filename ?? "",
                thermalState: ThermalGovernor.shared.thermalStatusDescription,
                currentGroupCount: 0
            )
            onProgress?(progress)
        }
        
        // Cluster using sub-linear Multi-Index Hashing
        let groups = DuplicateGrouper.group(
            assets: scannedSnapshots,
            includeSimilar: includeSimilar
        )
        
        let duration = Date().timeIntervalSince(startTime)
        
        return DedupeScanResult(
            scannedAt: Date(),
            durationSec: duration,
            totalScanned: scannedSnapshots.count,
            groups: groups,
            peakThermalState: ThermalGovernor.shared.thermalStatusDescription
        )
    }
    #endif
    
    // MARK: - Local File System Directory Scanner
    
    /// Scans a local folder of image files (JPEG, PNG, HEIC, TIFF, WebP) without heating the device.
    public func scanFolder(
        at folderURL: URL,
        includeSimilar: Bool = true,
        batchSize: Int = 30,
        onProgress: (@Sendable (ScanProgress) -> Void)? = nil
    ) async -> DedupeScanResult {
        let startTime = Date()
        
        let fileManager = FileManager.default
        let supportedExtensions = Set(["jpg", "jpeg", "png", "heic", "webp", "tiff", "gif", "bmp"])
        
        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.fileSizeKey, .creationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return DedupeScanResult(scannedAt: Date(), durationSec: 0, totalScanned: 0, groups: [])
        }
        
        var fileURLs: [URL] = []
        while let url = enumerator.nextObject() as? URL {
            let ext = url.pathExtension.lowercased()
            if supportedExtensions.contains(ext) {
                fileURLs.append(url)
            }
        }
        
        let totalCount = fileURLs.count
        var snapshots: [AssetSnapshot] = []
        snapshots.reserveCapacity(totalCount)
        
        var processedCount = 0
        
        for startIndex in stride(from: 0, to: totalCount, by: batchSize) {
            let endIndex = min(startIndex + batchSize, totalCount)
            
            autoreleasepool {
                for i in startIndex..<endIndex {
                    let url = fileURLs[i]
                    let filename = url.lastPathComponent
                    let values = try? url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
                    let fileSize = Int64(values?.fileSize ?? 0)
                    let creationDate = values?.creationDate ?? Date()
                    
                    var dualHash: DualHash?
                    var width = 1920
                    var height = 1080
                    
                    // Create CGImageSource with thumbnail option to avoid full image decompression
                    if let source = CGImageSourceCreateWithURL(url as CFURL, nil) {
                        let thumbOptions: [CFString: Any] = [
                            kCGImageSourceCreateThumbnailFromImageAlways: true,
                            kCGImageSourceThumbnailMaxPixelSize: 64,
                            kCGImageSourceCreateThumbnailWithTransform: true,
                            kCGImageSourceShouldCacheImmediately: true
                        ]
                        
                        if let cgThumb = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary) {
                            width = cgThumb.width
                            height = cgThumb.height
                            dualHash = DualHash.compute(from: cgThumb)
                        }
                    }
                    
                    let snap = AssetSnapshot(
                        id: url.path,
                        filename: filename,
                        creationDate: creationDate,
                        pixelWidth: width,
                        pixelHeight: height,
                        fileSize: fileSize,
                        dualHash: dualHash
                    )
                    
                    snapshots.append(snap)
                    processedCount += 1
                }
            }
            
            await ThermalGovernor.shared.applyThermalPacing()
            
            let progress = ScanProgress(
                processed: processedCount,
                total: totalCount,
                currentFilename: fileURLs[startIndex].lastPathComponent,
                thermalState: ThermalGovernor.shared.thermalStatusDescription,
                currentGroupCount: 0
            )
            onProgress?(progress)
        }
        
        let groups = DuplicateGrouper.group(
            assets: snapshots,
            includeSimilar: includeSimilar
        )
        
        let duration = Date().timeIntervalSince(startTime)
        
        return DedupeScanResult(
            scannedAt: Date(),
            durationSec: duration,
            totalScanned: snapshots.count,
            groups: groups,
            peakThermalState: ThermalGovernor.shared.thermalStatusDescription
        )
    }
}
