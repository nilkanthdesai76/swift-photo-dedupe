import Foundation

/// Fast Multi-Index Hashing (MIH) inverted index.
/// Partitions 64-bit hashes into 4 x 16-bit blocks (Pigeonhole Principle).
/// Enables near O(N) candidate retrieval for Hamming distance queries, eliminating O(N^2) CPU churning.
public final class MultiIndexHasher: @unchecked Sendable {
    
    public struct Entry: Sendable {
        public let id: String
        public let hash: DualHash
        
        public init(id: String, hash: DualHash) {
            self.id = id
            self.hash = hash
        }
    }
    
    // 8 Inverted index tables partitioning the 64-bit dHash and pHash into 8-bit bytes (Pigeonhole guarantee for distance <= 7)
    private var dTables: [[UInt8: [Int]]] = (0..<8).map { _ in [:] }
    private var pTables: [[UInt8: [Int]]] = (0..<8).map { _ in [:] }
    
    // Exact dHash table for instant O(1) exact duplicate identification
    private var exactDHashIndex: [UInt64: [Int]] = [:]
    
    private(set) public var entries: [Entry] = []
    
    public init() {}
    
    /// Inserts a photo entry into the multi-index tables in O(1) time.
    public func insert(id: String, hash: DualHash) {
        let index = entries.count
        entries.append(Entry(id: id, hash: hash))
        
        // Exact dHash index
        exactDHashIndex[hash.dHash, default: []].append(index)
        
        // 8-byte Pigeonhole partitions for dHash and pHash
        let d = hash.dHash
        let p = hash.pHash
        for i in 0..<8 {
            let dByte = UInt8((d >> (i * 8)) & 0xFF)
            let pByte = UInt8((p >> (i * 8)) & 0xFF)
            dTables[i][dByte, default: []].append(index)
            pTables[i][pByte, default: []].append(index)
        }
    }
    
    /// Finds candidate match indices for a given hash using O(1) bucket lookups.
    public func findCandidates(for hash: DualHash, maxDistance: Int = 8) -> Set<Int> {
        var candidates = Set<Int>()
        
        // Always include exact dHash matches
        if let exacts = exactDHashIndex[hash.dHash] {
            candidates.formUnion(exacts)
        }
        
        // Check 8-byte partitions across dHash and pHash
        let d = hash.dHash
        let p = hash.pHash
        for i in 0..<8 {
            let dByte = UInt8((d >> (i * 8)) & 0xFF)
            let pByte = UInt8((p >> (i * 8)) & 0xFF)
            if let dMatches = dTables[i][dByte] { candidates.formUnion(dMatches) }
            if let pMatches = pTables[i][pByte] { candidates.formUnion(pMatches) }
        }
        
        return candidates
    }
    
    /// Clears the index.
    public func reset() {
        for i in 0..<8 {
            dTables[i].removeAll(keepingCapacity: false)
            pTables[i].removeAll(keepingCapacity: false)
        }
        exactDHashIndex.removeAll(keepingCapacity: false)
        entries.removeAll(keepingCapacity: false)
    }
}
