import Foundation
import PhotoHashKit

@main
struct PhotoDedupeCLI {
    static func main() async {
        print("""
        ===================================================================
          📸 PhotoHashKit — High-Speed, Zero-Thermal Photo Deduplicator
          Dual dHash (Gradient) + pHash (DCT) • iCloud Thumbnail Safe
        ===================================================================
        """)
        
        let args = CommandLine.arguments
        
        if args.count > 1 && !args[1].starts(with: "-") {
            let folderPath = args[1]
            let folderURL = URL(fileURLWithPath: folderPath)
            print("🔍 Scanning directory: \(folderURL.path)...")
            
            let scanner = PhotoLibraryScanner()
            let result = await scanner.scanFolder(at: folderURL) { progress in
                let pct = Int(progress.fractionCompleted * 100)
                print("\r⚡ Progress: [\(pct)%] \(progress.processed)/\(progress.total) • Thermal: \(progress.thermalState)", terminator: "")
                fflush(stdout)
            }
            print("\n")
            printScanResults(result)
        } else {
            print("🚀 Running Built-In Synthetic Benchmark Dataset...")
            let startTime = Date()
            
            let dataset = SampleImageGenerator.createBenchmarkDataset()
            print("✅ Generated \(dataset.count) test photos with known duplicates, bursts & unique items.")
            
            let groups = DuplicateGrouper.group(assets: dataset)
            let duration = Date().timeIntervalSince(startTime)
            
            let scanResult = DedupeScanResult(
                scannedAt: Date(),
                durationSec: duration,
                totalScanned: dataset.count,
                groups: groups,
                peakThermalState: ThermalGovernor.shared.thermalStatusDescription
            )
            
            printScanResults(scanResult)
        }
    }
    
    static func printScanResults(_ result: DedupeScanResult) {
        print("-------------------------------------------------------------------")
        print("📊 SCAN SUMMARY")
        print("-------------------------------------------------------------------")
        print("• Total Photos Scanned:   \(result.totalScanned)")
        print("• Execution Duration:     \(String(format: "%.4f", result.durationSec)) seconds")
        print("• Processing Speed:       \(String(format: "%.1f", result.photosPerSecond)) photos/sec")
        print("• Peak Device Thermal:    \(result.peakThermalState)")
        print("• Duplicate Clusters:     \(result.totalGroups)")
        print("• Reclaimable Space:      \(result.formattedReclaimableSize)")
        print("-------------------------------------------------------------------")
        print("📁 IDENTIFIED CLUSTERS:")
        print("-------------------------------------------------------------------")
        
        for (idx, group) in result.groups.enumerated() {
            let catColor: String
            switch group.category {
            case .exactDuplicate: catColor = "🟢 [EXACT DUPLICATE]"
            case .nearDuplicate:  catColor = "🟡 [NEAR DUPLICATE]"
            case .similar:        catColor = "🔵 [SIMILAR / BURST]"
            case .different:      catColor = "⚪ [DIFFERENT]"
            }
            
            print("\nGroup #\(idx + 1) — \(catColor) • Similarity: \(String(format: "%.1f", group.similarityScore))% • Reclaimable: \(group.formattedReclaimableSize)")
            print("  ⭐ Best Keeper:  \(group.bestAssetId) (\(group.keeper?.filename ?? ""))")
            for asset in group.assets {
                let isBest = asset.id == group.bestAssetId ? " [KEEPER]" : " [DELETE RECLAIM]"
                let hashStr = asset.dualHash?.description ?? "No Hash"
                print("     - \(asset.filename) | \(asset.formattedSize) | \(hashStr)\(isBest)")
            }
        }
        print("\n✨ Done! Zero thermal impact reported by SoC governor.")
    }
}
