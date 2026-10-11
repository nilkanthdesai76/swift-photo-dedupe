import Foundation
import SwiftUI
import PhotoHashKit

#if canImport(Photos)
import Photos
#endif

public enum ScanMode: String, CaseIterable, Identifiable {
    case benchmark = "Synthetic Benchmark"
    case folder = "Folder Scan"
    case library = "Photos Library"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .benchmark: return "speedometer"
        case .folder: return "folder.badge.gearshape"
        case .library: return "photo.on.rectangle.angled"
        }
    }
}

@MainActor
public final class DedupeViewModel: ObservableObject {
    @Published public var selectedMode: ScanMode = .benchmark
    @Published public var isScanning: Bool = false
    @Published public var scanResult: DedupeScanResult?
    @Published public var selectedGroup: DuplicateGroup?
    @Published public var progress: ScanProgress?
    @Published public var thermalStateDescription: String = "Nominal (Cold)"
    @Published public var hasPhotoPermission: Bool = false
    @Published public var selectedFolderURL: URL?
    @Published public var includeSimilar: Bool = true
    
    private let scanner = PhotoLibraryScanner()
    
    public init() {
        self.thermalStateDescription = ThermalGovernor.shared.thermalStatusDescription
        ThermalGovernor.shared.addObserver { [weak self] _ in
            Task { @MainActor in
                self?.thermalStateDescription = ThermalGovernor.shared.thermalStatusDescription
            }
        }
        checkPhotoLibraryPermission()
    }
    
    public func checkPhotoLibraryPermission() {
        #if canImport(Photos)
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        self.hasPhotoPermission = (status == .authorized || status == .limited)
        #endif
    }
    
    public func requestPhotoLibraryPermission() async {
        #if canImport(Photos)
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        self.hasPhotoPermission = (status == .authorized || status == .limited)
        #endif
    }
    
    public func runBenchmark() {
        isScanning = true
        progress = ScanProgress(processed: 0, total: 17, currentFilename: "Generating test images...", thermalState: thermalStateDescription, currentGroupCount: 0)
        
        Task.detached(priority: .userInitiated) {
            let startTime = Date()
            let dataset = SampleImageGenerator.createBenchmarkDataset()
            let groups = DuplicateGrouper.group(assets: dataset, includeSimilar: true)
            let duration = Date().timeIntervalSince(startTime)
            
            let result = DedupeScanResult(
                scannedAt: Date(),
                durationSec: duration,
                totalScanned: dataset.count,
                groups: groups,
                peakThermalState: ThermalGovernor.shared.thermalStatusDescription
            )
            
            await MainActor.run {
                self.scanResult = result
                self.selectedGroup = result.groups.first
                self.isScanning = false
                self.progress = nil
            }
        }
    }
    
    public func scanSelectedFolder(url: URL) {
        selectedFolderURL = url
        isScanning = true
        scanResult = nil
        
        Task.detached(priority: .userInitiated) {
            let result = await self.scanner.scanFolder(
                at: url,
                includeSimilar: self.includeSimilar
            ) { prog in
                Task { @MainActor in
                    self.progress = prog
                }
            }
            
            await MainActor.run {
                self.scanResult = result
                self.selectedGroup = result.groups.first
                self.isScanning = false
                self.progress = nil
            }
        }
    }
    
    #if canImport(Photos)
    public func scanSystemLibrary() {
        isScanning = true
        scanResult = nil
        
        Task.detached(priority: .utility) {
            let result = await self.scanner.scanPhotoLibrary(
                includeSimilar: self.includeSimilar
            ) { prog in
                Task { @MainActor in
                    self.progress = prog
                }
            }
            
            await MainActor.run {
                self.scanResult = result
                self.selectedGroup = result.groups.first
                self.isScanning = false
                self.progress = nil
            }
        }
    }
    #endif
}
