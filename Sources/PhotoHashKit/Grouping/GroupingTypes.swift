import Foundation

/// A grouped cluster of duplicate or similar photos.
public struct DuplicateGroup: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let category: MatchCategory
    public let assets: [AssetSnapshot]
    public let bestAssetId: String
    public let similarityScore: Double
    public let reclaimableSize: Int64
    public let totalSize: Int64
    
    public init(
        id: String = UUID().uuidString,
        category: MatchCategory,
        assets: [AssetSnapshot],
        bestAssetId: String,
        similarityScore: Double
    ) {
        self.id = id
        self.category = category
        self.assets = assets
        self.bestAssetId = bestAssetId
        self.similarityScore = similarityScore
        
        let total = assets.reduce(Int64(0)) { $0 + $1.fileSize }
        self.totalSize = total
        
        // Reclaimable size = all assets in group except the keeper
        let reclaimable = assets
            .filter { $0.id != bestAssetId }
            .reduce(Int64(0)) { $0 + $1.fileSize }
        self.reclaimableSize = reclaimable
    }
    
    public var duplicateCount: Int {
        max(0, assets.count - 1)
    }
    
    public var formattedReclaimableSize: String {
        ByteCountFormatter.string(fromByteCount: reclaimableSize, countStyle: .file)
    }
    
    public var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    public var keeper: AssetSnapshot? {
        assets.first { $0.id == bestAssetId }
    }
}

/// Comprehensive scan outcome metadata.
public struct DedupeScanResult: Codable, Sendable {
    public let scannedAt: Date
    public let durationSec: Double
    public let totalScanned: Int
    public let groups: [DuplicateGroup]
    public let peakThermalState: String
    
    public init(
        scannedAt: Date = Date(),
        durationSec: Double,
        totalScanned: Int,
        groups: [DuplicateGroup],
        peakThermalState: String = "Nominal"
    ) {
        self.scannedAt = scannedAt
        self.durationSec = durationSec
        self.totalScanned = totalScanned
        self.groups = groups
        self.peakThermalState = peakThermalState
    }
    
    public var totalGroups: Int {
        groups.count
    }
    
    public var exactDuplicatesCount: Int {
        groups.filter { $0.category == .exactDuplicate }.reduce(0) { $0 + $1.duplicateCount }
    }
    
    public var nearDuplicatesCount: Int {
        groups.filter { $0.category == .nearDuplicate }.reduce(0) { $0 + $1.duplicateCount }
    }
    
    public var similarCount: Int {
        groups.filter { $0.category == .similar }.reduce(0) { $0 + $1.duplicateCount }
    }
    
    public var totalReclaimableBytes: Int64 {
        groups.reduce(Int64(0)) { $0 + $1.reclaimableSize }
    }
    
    public var formattedReclaimableSize: String {
        ByteCountFormatter.string(fromByteCount: totalReclaimableBytes, countStyle: .file)
    }
    
    public var photosPerSecond: Double {
        durationSec > 0 ? Double(totalScanned) / durationSec : 0
    }
}
