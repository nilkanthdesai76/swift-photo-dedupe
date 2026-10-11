import XCTest
@testable import PhotoHashKit

final class PhotoHashKitTests: XCTestCase {
    
    // MARK: - dHash Tests
    
    func testDHashIdenticalImagesHaveZeroDistance() {
        guard let img1 = SampleImageGenerator.generateTestImage(baseColor: (r: 0.5, g: 0.5, b: 0.5)),
              let img2 = SampleImageGenerator.generateTestImage(baseColor: (r: 0.5, g: 0.5, b: 0.5)) else {
            XCTFail("Failed to generate test images")
            return
        }
        
        guard let hash1 = DHash.compute(from: img1),
              let hash2 = DHash.compute(from: img2) else {
            XCTFail("Failed to compute dHash")
            return
        }
        
        let dist = DHash.distance(hash1, hash2)
        XCTAssertEqual(dist, 0, "Identical images must have dHash Hamming distance = 0")
    }
    
    func testDHashDistinctImagesHaveHighDistance() {
        guard let img1 = SampleImageGenerator.generateTestImage(baseColor: (r: 0.1, g: 0.1, b: 0.1)),
              let img2 = SampleImageGenerator.generateTestImage(baseColor: (r: 0.9, g: 0.8, b: 0.2), shapeOffset: CGPoint(x: 50, y: 50)) else {
            XCTFail("Failed to generate test images")
            return
        }
        
        guard let hash1 = DHash.compute(from: img1),
              let hash2 = DHash.compute(from: img2) else {
            XCTFail("Failed to compute dHash")
            return
        }
        
        let dist = DHash.distance(hash1, hash2)
        XCTAssertGreaterThan(dist, 5, "Distinct images should have significant dHash distance")
    }
    
    // MARK: - pHash Tests
    
    func testPHashIdenticalImagesHaveZeroDistance() {
        guard let img1 = SampleImageGenerator.generateTestImage(baseColor: (r: 0.3, g: 0.6, b: 0.9)),
              let img2 = SampleImageGenerator.generateTestImage(baseColor: (r: 0.3, g: 0.6, b: 0.9)) else {
            XCTFail("Failed to generate test images")
            return
        }
        
        guard let hash1 = PHash.compute(from: img1),
              let hash2 = PHash.compute(from: img2) else {
            XCTFail("Failed to compute pHash")
            return
        }
        
        let dist = PHash.distance(hash1, hash2)
        XCTAssertEqual(dist, 0, "Identical images must have pHash Hamming distance = 0")
    }
    
    func testPHashResilientToNoiseAndCompression() {
        guard let base = SampleImageGenerator.generateTestImage(baseColor: (r: 0.7, g: 0.2, b: 0.3), shapeOffset: CGPoint(x: 25, y: 18), pattern: 3),
              let noisy = SampleImageGenerator.generateTestImage(baseColor: (r: 0.71, g: 0.21, b: 0.3), shapeOffset: CGPoint(x: 25, y: 18), pattern: 3, addNoise: true) else {
            XCTFail("Failed to generate test images")
            return
        }
        
        guard let hash1 = PHash.compute(from: base),
              let hash2 = PHash.compute(from: noisy) else {
            XCTFail("Failed to compute pHash")
            return
        }
        
        let dist = PHash.distance(hash1, hash2)
        XCTAssertLessThanOrEqual(dist, 4, "pHash should be resilient to slight noise and minor color shifts")
    }
    
    // MARK: - DualHash & MultiIndexHasher Tests
    
    func testMultiIndexHasherRetrieval() {
        let mih = MultiIndexHasher()
        
        let hashA = DualHash(dHash: 0x0123456789ABCDEF, pHash: 0xFEDCBA9876543210)
        let hashB = DualHash(dHash: 0x0123456789ABCDEF, pHash: 0xFEDCBA9876543211) // 1-bit diff
        let hashC = DualHash(dHash: 0xAAAAAAAAAAAAAAAA, pHash: 0x5555555555555555) // completely distinct
        
        mih.insert(id: "A", hash: hashA)
        mih.insert(id: "B", hash: hashB)
        mih.insert(id: "C", hash: hashC)
        
        let candidatesForA = mih.findCandidates(for: hashA)
        XCTAssertTrue(candidatesForA.contains(0), "Should find self")
        XCTAssertTrue(candidatesForA.contains(1), "Should find near neighbor B")
    }
    
    // MARK: - DuplicateGrouper Tests
    
    func testSyntheticBenchmarkGrouping() {
        let dataset = SampleImageGenerator.createBenchmarkDataset()
        XCTAssertEqual(dataset.count, 17, "Dataset must have 17 test assets")
        
        let groups = DuplicateGrouper.group(assets: dataset)
        XCTAssertEqual(groups.count, 3, "DuplicateGrouper should detect exactly 3 distinct clusters")
        
        // Should find the exact duplicate cluster
        let exactGroup = groups.first { $0.category == .exactDuplicate }
        XCTAssertNotNil(exactGroup, "Must identify exact duplicate group")
        XCTAssertEqual(exactGroup?.assets.count, 3, "Exact group has 3 copies")
        
        // Should find the near duplicate cluster
        let nearGroup = groups.first { $0.category == .nearDuplicate }
        XCTAssertNotNil(nearGroup, "Must identify near duplicate group")
        XCTAssertEqual(nearGroup?.assets.count, 2, "Near duplicate group has 2 copies")
        
        // Should find the similar burst cluster
        let similarGroup = groups.first { $0.category == .similar }
        XCTAssertNotNil(similarGroup, "Must identify similar burst group")
        XCTAssertEqual(similarGroup?.assets.count, 4, "Burst group has 4 frames")
        
        // Total reclaimable size must be positive
        let totalReclaimable = groups.reduce(Int64(0)) { $0 + $1.reclaimableSize }
        XCTAssertGreaterThan(totalReclaimable, 0)
    }
    
    // MARK: - BestPhotoSelector Tests
    
    func testBestPhotoSelectorPrefersFavoriteAndHigherResolution() {
        let asset1 = AssetSnapshot(id: "1", filename: "low.jpg", pixelWidth: 1000, pixelHeight: 1000, fileSize: 100_000, isFavorite: false)
        let asset2 = AssetSnapshot(id: "2", filename: "high.jpg", pixelWidth: 4000, pixelHeight: 3000, fileSize: 4_000_000, isFavorite: false)
        let asset3 = AssetSnapshot(id: "3", filename: "fav.jpg", pixelWidth: 2000, pixelHeight: 2000, fileSize: 500_000, isFavorite: true)
        
        // Favorite wins even if resolution is lower
        let bestWithFav = BestPhotoSelector.pickBest(from: [asset1, asset2, asset3])
        XCTAssertEqual(bestWithFav, "3")
        
        // Higher resolution wins when no favorite
        let bestNoFav = BestPhotoSelector.pickBest(from: [asset1, asset2])
        XCTAssertEqual(bestNoFav, "2")
    }
    
    // MARK: - MatchCategory & Reclaimable Size Tests
    
    func testMatchCategoryClassification() {
        let h1 = DualHash(dHash: 0x1111222233334444, pHash: 0x5555666677778888)
        let hExact = DualHash(dHash: 0x1111222233334444, pHash: 0x5555666677778888)
        let hNear = DualHash(dHash: 0x1111222233334445, pHash: 0x5555666677778889) // 2-bit diff
        let hDiff = DualHash(dHash: 0x9999888877776666, pHash: 0x11110000FFFFEEEE)
        
        XCTAssertEqual(h1.matchCategory(to: hExact), .exactDuplicate)
        XCTAssertEqual(h1.matchCategory(to: hNear), .nearDuplicate)
        XCTAssertEqual(h1.matchCategory(to: hDiff), .different)
    }
    
    func testReclaimableSizeCalculation() {
        let a1 = AssetSnapshot(id: "1", filename: "1.jpg", pixelWidth: 1000, pixelHeight: 1000, fileSize: 1_000_000, isFavorite: false)
        let a2 = AssetSnapshot(id: "2", filename: "2.jpg", pixelWidth: 1000, pixelHeight: 1000, fileSize: 1_000_000, isFavorite: false)
        let a3 = AssetSnapshot(id: "3", filename: "3.jpg", pixelWidth: 1000, pixelHeight: 1000, fileSize: 2_000_000, isFavorite: true) // Keeper (2MB)
        
        let group = DuplicateGroup(
            category: .exactDuplicate,
            assets: [a1, a2, a3],
            bestAssetId: "3",
            similarityScore: 1.0
        )
        
        XCTAssertEqual(group.totalSize, 4_000_000)
        XCTAssertEqual(group.reclaimableSize, 2_000_000) // a1 + a2
        XCTAssertEqual(group.nonKeepers.count, 2)
        XCTAssertEqual(group.keeper?.id, "3")
    }
    
    func testThermalGovernorStatus() {
        let governor = ThermalGovernor.shared
        XCTAssertGreaterThanOrEqual(governor.recommendedConcurrency, 1)
        XCTAssertFalse(governor.thermalStatusDescription.isEmpty)
    }
}

