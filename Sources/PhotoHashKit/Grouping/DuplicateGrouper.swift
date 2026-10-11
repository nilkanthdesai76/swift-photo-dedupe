import Foundation

/// Fast Union-Find (Disjoint Set Union) for grouping connected components.
private final class DisjointSetUnion {
    private var parent: [Int]
    private var rank: [Int]
    
    init(count: Int) {
        self.parent = Array(0..<count)
        self.rank = [Int](repeating: 0, count: count)
    }
    
    func find(_ i: Int) -> Int {
        if parent[i] == i { return i }
        parent[i] = find(parent[i])
        return parent[i]
    }
    
    func union(_ x: Int, _ y: Int) {
        let rootX = find(x)
        let rootY = find(y)
        if rootX == rootY { return }
        
        if rank[rootX] < rank[rootY] {
            parent[rootX] = rootY
        } else if rank[rootX] > rank[rootY] {
            parent[rootY] = rootX
        } else {
            parent[rootY] = rootX
            rank[rootX] += 1
        }
    }
}

/// High-throughput clustering engine using Multi-Index Hashing and Disjoint-Set Union.
public enum DuplicateGrouper {
    
    public struct Thresholds: Sendable {
        public let exactDHashMax: Int
        public let exactPHashMax: Int
        public let nearDHashMax: Int
        public let nearPHashMax: Int
        public let similarDHashMax: Int
        public let similarPHashMax: Int
        
        public static let standard = Thresholds(
            exactDHashMax: 0,
            exactPHashMax: 0,
            nearDHashMax: 3,
            nearPHashMax: 4,
            similarDHashMax: 7,
            similarPHashMax: 8
        )
    }
    
    /// Groups an array of hashed assets into duplicate clusters.
    public static func group(
        assets: [AssetSnapshot],
        thresholds: Thresholds = .standard,
        includeSimilar: Bool = true
    ) -> [DuplicateGroup] {
        guard assets.count >= 2 else { return [] }
        
        // 1. Build Multi-Index Inverted Index
        let mih = MultiIndexHasher()
        for asset in assets {
            if let hash = asset.dualHash {
                mih.insert(id: asset.id, hash: hash)
            }
        }
        
        let n = assets.count
        let dsu = DisjointSetUnion(count: n)
        
        // Pairwise similarity cache for categorizing groups
        var pairCategories: [UInt64: MatchCategory] = [:]
        
        func pairKey(_ a: Int, _ b: Int) -> UInt64 {
            let lo = UInt64(min(a, b))
            let hi = UInt64(max(a, b))
            return (lo << 32) | hi
        }
        
        // 2. Query candidates per asset using O(1) multi-index lookups
        for i in 0..<n {
            guard let hashI = assets[i].dualHash else { continue }
            
            let candidateIndices = mih.findCandidates(for: hashI, maxDistance: thresholds.similarPHashMax)
            
            for j in candidateIndices where j > i {
                guard let hashJ = assets[j].dualHash else { continue }
                
                let dDist = hashI.dDistance(to: hashJ)
                let pDist = hashI.pDistance(to: hashJ)
                
                var matched = false
                var category: MatchCategory = .different
                
                if dDist <= thresholds.exactDHashMax && pDist <= thresholds.exactPHashMax {
                    matched = true
                    category = .exactDuplicate
                } else if dDist <= thresholds.nearDHashMax && pDist <= thresholds.nearPHashMax {
                    matched = true
                    category = .nearDuplicate
                } else if includeSimilar && dDist <= thresholds.similarDHashMax && pDist <= thresholds.similarPHashMax {
                    matched = true
                    category = .similar
                }
                
                if matched {
                    dsu.union(i, j)
                    pairCategories[pairKey(i, j)] = category
                }
            }
        }
        
        // 3. Collect assets by their root parent in DSU
        var clusters: [Int: [Int]] = [:]
        for i in 0..<n {
            guard assets[i].dualHash != nil else { continue }
            let root = dsu.find(i)
            clusters[root, default: []].append(i)
        }
        
        // 4. Transform multi-item clusters into DuplicateGroup objects
        var resultGroups: [DuplicateGroup] = []
        
        for (_, indices) in clusters where indices.count >= 2 {
            let groupAssets = indices.map { assets[$0] }
            
            // Determine worst-case or dominant category in the cluster
            var isAllExact = true
            var isAllNear = true
            var totalSimilarity = 0.0
            var comparisons = 0
            
            for a in 0..<indices.count {
                for b in (a + 1)..<indices.count {
                    let idxA = indices[a]
                    let idxB = indices[b]
                    let cat = pairCategories[pairKey(idxA, idxB)] ?? .similar
                    if cat != .exactDuplicate { isAllExact = false }
                    if cat != .exactDuplicate && cat != .nearDuplicate { isAllNear = false }
                    
                    if let hashA = assets[idxA].dualHash, let hashB = assets[idxB].dualHash {
                        totalSimilarity += hashA.similarityScore(to: hashB)
                        comparisons += 1
                    }
                }
            }
            
            let groupCategory: MatchCategory = isAllExact ? .exactDuplicate : (isAllNear ? .nearDuplicate : .similar)
            let avgScore = comparisons > 0 ? (totalSimilarity / Double(comparisons)) : 95.0
            let bestId = BestPhotoSelector.pickBest(from: groupAssets)
            
            resultGroups.append(
                DuplicateGroup(
                    category: groupCategory,
                    assets: groupAssets,
                    bestAssetId: bestId,
                    similarityScore: avgScore
                )
            )
        }
        
        // Sort by reclaimable size descending
        return resultGroups.sorted { $0.reclaimableSize > $1.reclaimableSize }
    }
}
