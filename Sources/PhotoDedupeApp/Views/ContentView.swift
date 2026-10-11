import SwiftUI
import PhotoHashKit

public struct ContentView: View {
    @StateObject private var viewModel = DedupeViewModel()
    @State private var showingFolderPicker = false
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView {
            // Left Sidebar
            VStack(alignment: .leading, spacing: 16) {
                // App Branding Header
                HStack(spacing: 10) {
                    Image(systemName: "camera.macro")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.blue)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("PhotoHashKit")
                            .font(.system(size: 14, weight: .black))
                        Text("Zero-Heat Duplicate Deduper")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                
                // Live Thermal Gauge
                ThermalGaugeView(viewModel: viewModel)
                    .padding(.horizontal, 10)
                
                Divider()
                
                // Scan Modes Picker
                VStack(alignment: .leading, spacing: 4) {
                    Text("SCAN SOURCE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                    
                    ForEach(ScanMode.allCases) { mode in
                        Button {
                            viewModel.selectedMode = mode
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: mode.iconName)
                                    .frame(width: 18)
                                Text(mode.rawValue)
                                    .font(.system(size: 12, weight: .medium))
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(viewModel.selectedMode == mode ? Color.blue.opacity(0.12) : Color.clear)
                            )
                            .foregroundStyle(viewModel.selectedMode == mode ? Color.blue : Color.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
                
                Divider()
                
                // Primary Action Button
                VStack(spacing: 8) {
                    switch viewModel.selectedMode {
                    case .benchmark:
                        Button {
                            viewModel.runBenchmark()
                        } label: {
                            HStack {
                                Image(systemName: "bolt.fill")
                                Text(viewModel.isScanning ? "Scanning..." : "Run Benchmark (17 Photos)")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isScanning)
                        
                    case .folder:
                        Button {
                            selectFolder()
                        } label: {
                            HStack {
                                Image(systemName: "folder")
                                Text(viewModel.isScanning ? "Scanning..." : "Choose Folder...")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isScanning)
                        
                    case .library:
                        #if canImport(Photos)
                        if viewModel.hasPhotoPermission {
                            Button {
                                viewModel.scanSystemLibrary()
                            } label: {
                                HStack {
                                    Image(systemName: "photo.stack")
                                    Text(viewModel.isScanning ? "Scanning..." : "Scan Photo Library")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(viewModel.isScanning)
                        } else {
                            Button {
                                Task {
                                    await viewModel.requestPhotoLibraryPermission()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "lock.open")
                                    Text("Grant Photos Access")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        #endif
                    }
                    
                    Toggle("Include Similar / Bursts", isOn: $viewModel.includeSimilar)
                        .font(.system(size: 11))
                        .padding(.horizontal, 8)
                }
                .padding(.horizontal, 10)
                
                // Live Progress
                if viewModel.isScanning, let progress = viewModel.progress {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: progress.fractionCompleted)
                            .progressViewStyle(.linear)
                        
                        HStack {
                            Text("\(progress.processed)/\(progress.total)")
                                .font(.system(size: 10, design: .monospaced))
                            Spacer()
                            Text(progress.thermalState)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 12)
                }
                
                Spacer()
                
                // Summary Stats
                if let res = viewModel.scanResult {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SCAN STATS")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                        
                        HStack {
                            Text("Total Scanned:")
                            Spacer()
                            Text("\(res.totalScanned)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                        }
                        HStack {
                            Text("Duplicate Groups:")
                            Spacer()
                            Text("\(res.totalGroups)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                        }
                        HStack {
                            Text("Speed:")
                            Spacer()
                            Text("\(String(format: "%.0f", res.photosPerSecond)) p/s")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(.blue)
                        }
                        HStack {
                            Text("Reclaimable:")
                            Spacer()
                            Text(res.formattedReclaimableSize)
                                .font(.system(size: 12, weight: .black, design: .monospaced))
                                .foregroundStyle(.green)
                        }
                    }
                    .font(.system(size: 11))
                    .padding(10)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 10)
                    .padding(.bottom, 12)
                }
            }
            .frame(minWidth: 260, idealWidth: 280)
            
        } content: {
            // Middle Content: Duplicate Clusters List
            if let result = viewModel.scanResult {
                if result.groups.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 42))
                            .foregroundStyle(.green)
                        Text("No Duplicates Found")
                            .font(.system(size: 16, weight: .bold))
                        Text("All scanned photos have distinct visual content.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(selection: $viewModel.selectedGroup) {
                        Section("IDENTIFIED CLUSTERS (\(result.groups.count))") {
                            ForEach(result.groups) { group in
                                NavigationLink(value: group) {
                                    HStack(spacing: 10) {
                                        Circle()
                                            .fill(badgeColor(for: group.category))
                                            .frame(width: 8, height: 8)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack {
                                                Text(group.category.rawValue)
                                                    .font(.system(size: 12, weight: .bold))
                                                Spacer()
                                                Text("\(group.assets.count) photos")
                                                    .font(.system(size: 11, design: .monospaced))
                                                    .foregroundStyle(.secondary)
                                            }
                                            
                                            HStack {
                                                Text("\(String(format: "%.1f", group.similarityScore))% match")
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(.secondary)
                                                Spacer()
                                                Text(group.formattedReclaimableSize)
                                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                                    .foregroundStyle(.green)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                    .listStyle(.sidebar)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 52))
                        .foregroundStyle(.secondary.opacity(0.4))
                    
                    VStack(spacing: 4) {
                        Text("Ready to Find Duplicates")
                            .font(.system(size: 16, weight: .bold))
                        Text("Uses dual dHash (gradient) & pHash (frequency DCT) with sub-linear Multi-Index Hashing.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 320)
                    }
                    
                    Button("Run Synthetic Benchmark") {
                        viewModel.runBenchmark()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } detail: {
            // Right Detail: Group Side-by-Side Comparison
            if let group = viewModel.selectedGroup {
                GroupDetailView(group: group)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "square.split.2x1")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary.opacity(0.4))
                    Text("Select a duplicate cluster to inspect side-by-side metrics.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    private func selectFolder() {
        #if canImport(AppKit)
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.scanSelectedFolder(url: url)
        }
        #endif
    }
    
    private func badgeColor(for category: MatchCategory) -> Color {
        switch category {
        case .exactDuplicate: return .green
        case .nearDuplicate: return .yellow
        case .similar: return .blue
        case .different: return .gray
        }
    }
}
