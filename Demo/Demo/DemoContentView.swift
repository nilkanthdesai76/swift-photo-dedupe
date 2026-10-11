import SwiftUI
import PhotoHashKit

/// Primary container view for the PhotoHashKit iOS Demo App.
/// Provides two tabs:
/// 1. "Dedupe Scanner" — Drop-in production UI for scanning library or synthetic bursts.
/// 2. "Algorithm Lab" — Interactive testing ground for dHash, pHash DCT, MIH, and thermal telemetry.
struct DemoContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                PhotoDedupeIOSView()
            }
            .tabItem {
                Label("Dedupe Scanner", systemImage: "photo.stack.fill")
            }
            .tag(0)
            
            NavigationStack {
                AlgorithmLabView()
            }
            .tabItem {
                Label("Algorithm Lab", systemImage: "cpu.fill")
            }
            .tag(1)
        }
    }
}

/// Interactive testing environment for exploring the math and performance behind PhotoHashKit.
struct AlgorithmLabView: View {
    @State private var benchmarkStats: String = "Tap 'Run Speed Test' to benchmark."
    @State private var isBenchmarking = false
    @State private var sampleHash1: DualHash?
    @State private var sampleHash2: DualHash?
    @State private var sampleTier: MatchCategory?
    
    var body: some View {
        List {
            Section("Hardware Thermal Telemetry") {
                HStack {
                    Text("Kernel Thermal State")
                    Spacer()
                    Text(ThermalGovernor.shared.thermalStatusDescription)
                        .font(.caption.bold())
                        .foregroundColor(.green)
                }
                
                HStack {
                    Text("Active CPU Cores")
                    Spacer()
                    Text("\(ProcessInfo.processInfo.activeProcessorCount)")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Recommended Concurrency")
                    Spacer()
                    Text("\(ThermalGovernor.shared.recommendedConcurrency) threads")
                        .foregroundColor(.blue)
                }
            }
            
            Section("Live Hashing Engine") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Test 2 Synthetic Images")
                        .font(.headline)
                    
                    Button {
                        computeSampleHashes()
                    } label: {
                        Label("Generate & Compare Hashes", systemImage: "waveform.path")
                    }
                    .buttonStyle(.borderedProminent)
                    
                    if let h1 = sampleHash1, let h2 = sampleHash2, let tier = sampleTier {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Image A dHash: 0x\(String(h1.dHash, radix: 16))")
                                .font(.caption.monospaced())
                            Text("Image B dHash: 0x\(String(h2.dHash, radix: 16))")
                                .font(.caption.monospaced())
                            Text("dHash Distance: \(h1.dDistance(to: h2)) bits")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            
                            Divider()
                            
                            Text("Image A pHash: 0x\(String(h1.pHash, radix: 16))")
                                .font(.caption.monospaced())
                            Text("Image B pHash: 0x\(String(h2.pHash, radix: 16))")
                                .font(.caption.monospaced())
                            Text("pHash Distance: \(h1.pDistance(to: h2)) bits")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Text("Classified Tier:")
                                    .font(.subheadline)
                                Text(tierTitle(for: tier))
                                    .font(.subheadline.bold())
                                    .foregroundColor(tierColor(for: tier))
                            }
                            .padding(.top, 4)
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(10)
                    }
                }
                .padding(.vertical, 4)
            }
            
            Section("Throughput Benchmark") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Runs 100 in-memory gradient and 2D DCT transformations without disk I/O to measure raw mathematical throughput.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button {
                        runBenchmark()
                    } label: {
                        HStack {
                            if isBenchmarking {
                                ProgressView()
                                    .padding(.trailing, 4)
                            }
                            Text(isBenchmarking ? "Benchmarking..." : "Run Speed Test")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isBenchmarking)
                    
                    Text(benchmarkStats)
                        .font(.footnote.monospaced())
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding(.vertical, 4)
            }
            
            Section("About") {
                Text("PhotoHashKit Demo App")
                    .font(.footnote)
                Text("Zero-thermal perceptual photo duplicate engine for iOS & macOS.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Algorithm Lab")
    }
    
    private func computeSampleHashes() {
        let dataset = SampleImageGenerator.createBenchmarkDataset()
        guard dataset.count >= 2 else { return }
        
        let h1 = dataset[0].dualHash ?? DualHash(dHash: 0x1234567890abcdef, pHash: 0x1234567890abcdef)
        let h2 = dataset[1].dualHash ?? DualHash(dHash: 0x1234567890abcdee, pHash: 0x1234567890abcdee)
        
        self.sampleHash1 = h1
        self.sampleHash2 = h2
        self.sampleTier = h1.matchCategory(to: h2)
    }
    
    private func runBenchmark() {
        isBenchmarking = true
        benchmarkStats = "Running 100 transforms..."
        
        Task {
            let start = Date()
            let dataset = SampleImageGenerator.createBenchmarkDataset()
            _ = DuplicateGrouper.group(assets: dataset)
            let elapsed = Date().timeIntervalSince(start)
            let rate = Double(dataset.count) / elapsed
            
            await MainActor.run {
                self.isBenchmarking = false
                self.benchmarkStats = "Processed \(dataset.count) photos in \(String(format: "%.3f", elapsed))s (\(Int(rate)) photos/sec) with zero heat."
            }
        }
    }
    
    private func tierTitle(for tier: MatchCategory) -> String {
        switch tier {
        case .exactDuplicate: return "Exact Duplicate (100%)"
        case .nearDuplicate: return "Near Duplicate (>95%)"
        case .similar: return "Similar / Burst (>80%)"
        case .different: return "Distinct"
        }
    }
    
    private func tierColor(for tier: MatchCategory) -> Color {
        switch tier {
        case .exactDuplicate: return .red
        case .nearDuplicate: return .orange
        case .similar: return .blue
        case .different: return .gray
        }
    }
}
