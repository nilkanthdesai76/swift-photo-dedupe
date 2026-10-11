import Foundation
import CoreGraphics

/// Match classification tiers based on dual dHash + pHash Hamming distances.
public enum MatchCategory: String, Codable, Sendable, CaseIterable {
    /// 100% identical pixel visual content (dDistance = 0, pDistance = 0).
    case exactDuplicate = "Exact Duplicate"
    
    /// Re-saved from WhatsApp/AirDrop, minor recompression, slight exposure variation.
    case nearDuplicate = "Near Duplicate"
    
    /// Burst shot, slight pose change, angle shift, or compositionally identical.
    case similar = "Similar / Burst"
    
    /// Distinct non-matching photos.
    case different = "Different"
}

/// Composite 16-byte dual perceptual fingerprint combining dHash (structure) and pHash (frequencies).
public struct DualHash: Hashable, Codable, Sendable, CustomStringConvertible {
    public let dHash: UInt64
    public let pHash: UInt64
    
    public init(dHash: UInt64, pHash: UInt64) {
        self.dHash = dHash
        self.pHash = pHash
    }
    
    /// Computes both dHash and pHash from a CGImage in a single pipeline.
    public static func compute(from cgImage: CGImage) -> DualHash? {
        guard let d = DHash.compute(from: cgImage),
              let p = PHash.compute(from: cgImage) else {
            return nil
        }
        return DualHash(dHash: d, pHash: p)
    }
    
    /// Computes Hamming distance between dHashes (0...64).
    @inlinable
    public func dDistance(to other: DualHash) -> Int {
        (dHash ^ other.dHash).nonzeroBitCount
    }
    
    /// Computes Hamming distance between pHashes (0...64).
    @inlinable
    public func pDistance(to other: DualHash) -> Int {
        (pHash ^ other.pHash).nonzeroBitCount
    }
    
    /// Determines similarity category against another fingerprint.
    public func matchCategory(to other: DualHash) -> MatchCategory {
        let d = dDistance(to: other)
        let p = pDistance(to: other)
        
        if d == 0 && p == 0 {
            return .exactDuplicate
        } else if d <= 3 && p <= 4 {
            return .nearDuplicate
        } else if d <= 7 && p <= 8 {
            return .similar
        } else {
            return .different
        }
    }
    
    /// Similarity percentage (0.0% to 100.0%) based on weighted combination.
    public func similarityScore(to other: DualHash) -> Double {
        let dDist = Double(dDistance(to: other))
        let pDist = Double(pDistance(to: other))
        // Average bit distance normalized over 64 bits
        let avgDist = (dDist * 0.45 + pDist * 0.55)
        let score = max(0.0, min(100.0, (1.0 - (avgDist / 64.0)) * 100.0))
        return score
    }
    
    public var dHashHex: String {
        String(format: "%016llX", dHash)
    }
    
    public var pHashHex: String {
        String(format: "%016llX", pHash)
    }
    
    public var description: String {
        "DualHash(d: \(dHashHex), p: \(pHashHex))"
    }
}
