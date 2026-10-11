#if os(iOS)
import SwiftUI
#if canImport(Photos)
import Photos
#endif

/// Complete, drop-in iOS view for duplicate photo detection and cleaning.
/// Developers can embed this directly into any iOS app navigation stack or tab bar:
///
/// ```swift
/// NavigationStack {
///     PhotoDedupeIOSView()
/// }
/// ```
public struct PhotoDedupeIOSView: View {
    @StateObject private var viewModel = PhotoDedupeIOSViewModel()
    @State private var comparingGroup: DuplicateGroup?
    @State private var showingTrashConfirmation = false
    
    public init() {}
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 20) {
                    // Thermal & System Telemetry Header
                    telemetryHeader
                    
                    // Main Action Buttons
                    actionButtons
                    
                    // Active Scanning Progress
                    if viewModel.isScanning {
                        scanProgressCard
                    }
                    
                    // Filter Picker (if results exist)
                    if let result = viewModel.scanResult, !result.groups.isEmpty {
                        categoryFilterPicker(result: result)
                    }
                    
                    // Duplicate Groups Content
                    duplicateGroupsSection
                }
                .padding(.horizontal)
                .padding(.bottom, viewModel.scanResult?.groups.isEmpty == false ? 90 : 20)
            }
            
            // Bottom Sticky Clean Bar
            if let result = viewModel.scanResult, !result.groups.isEmpty {
                bottomCleanBar(result: result)
            }
        }
        .navigationTitle("Photo Dedupe")
        .sheet(item: $comparingGroup) { group in
            PhotoComparisonSheet(
                group: group,
                onSelectKeeper: { newKeeperId in
                    viewModel.setKeeper(groupId: group.id, newKeeperId: newKeeperId)
                },
                onTrashGroup: {
                    Task {
                        await viewModel.trashDuplicates(in: group)
                    }
                }
            )
        }
        .confirmationDialog(
            "Clean All Duplicates?",
            isPresented: $showingTrashConfirmation,
            titleVisibility: .visible
        ) {
            Button("Move Non-Keepers to Recently Deleted", role: .destructive) {
                Task {
                    await viewModel.trashAllDuplicates()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will move all unselected duplicate photos (\(viewModel.formattedReclaimableSize)) to your 'Recently Deleted' album. No photos will be permanently deleted.")
        }
    }
    
    // MARK: - Subviews
    
    private var telemetryHeader: some View {
        HStack {
            Label(viewModel.thermalDescription, systemImage: "thermometer.sun.fill")
                .font(.caption.bold())
                .foregroundColor(thermalColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(thermalColor.opacity(0.12))
                .cornerRadius(20)
            
            Spacer()
            
            if let result = viewModel.scanResult {
                Text("\(result.totalScanned) photos in \(String(format: "%.1f", result.durationSec))s")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var thermalColor: Color {
        if viewModel.thermalDescription.contains("Nominal") {
            return .green
        } else if viewModel.thermalDescription.contains("Fair") {
            return .orange
        } else {
            return .red
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                Task {
                    await viewModel.startLibraryScan()
                }
            } label: {
                HStack {
                    Image(systemName: "photo.on.rectangle.angled")
                    Text("Scan Library")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isScanning)
            
            Button {
                viewModel.runSyntheticBenchmark()
            } label: {
                HStack {
                    Image(systemName: "bolt.fill")
                    Text("Synthetic Test")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isScanning)
        }
    }
    
    private var scanProgressCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let progress = viewModel.scanProgress {
                HStack {
                    Text("Scanning Photo Library...")
                        .font(.subheadline.bold())
                    Spacer()
                    Text("\(progress.processedCount) / \(progress.totalCount)")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: progress.fractionCompleted)
                    .tint(.blue)
                
                HStack {
                    Text("\(Int(progress.fractionCompleted * 100))% Complete")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Throttled for zero heat")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            } else {
                HStack {
                    ProgressView()
                    Text("Preparing photos...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 8)
                }
            }
        }
        .padding()
        .background(Color.dedupeCardBackground)
        .cornerRadius(12)
    }
    
    private func categoryFilterPicker(result: DedupeScanResult) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(title: "All (\(result.groups.count))", filter: nil)
                filterChip(title: "Exact (\(result.exactDuplicatesCount))", filter: .exactDuplicate)
                filterChip(title: "Near (\(result.nearDuplicatesCount))", filter: .nearDuplicate)
                filterChip(title: "Similar (\(result.similarCount))", filter: .similar)
            }
            .padding(.vertical, 4)
        }
    }
    
    private func filterChip(title: String, filter: MatchCategory?) -> some View {
        let isSelected = viewModel.selectedFilter == filter
        
        return Button {
            viewModel.selectedFilter = filter
        } label: {
            Text(title)
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.dedupeSubBackground)
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
    
    @ViewBuilder
    private var duplicateGroupsSection: some View {
        if let result = viewModel.scanResult {
            if result.groups.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("No Duplicates Found")
                        .font(.headline)
                    Text("Your photo library is clean and clutter-free!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.filteredGroups) { group in
                        DuplicateGroupIOSCard(
                            group: group,
                            onSelectKeeper: { newKeeperId in
                                viewModel.setKeeper(groupId: group.id, newKeeperId: newKeeperId)
                            },
                            onCompare: {
                                comparingGroup = group
                            },
                            onTrashGroup: {
                                Task {
                                    await viewModel.trashDuplicates(in: group)
                                }
                            }
                        )
                    }
                }
            }
        } else if !viewModel.isScanning {
            VStack(spacing: 12) {
                Image(systemName: "photo.stack")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("Ready to Scan")
                    .font(.headline)
                Text("Tap 'Scan Library' to analyze your photos using hardware-accelerated dHash and pHash with zero thermal impact.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(.top, 40)
        }
    }
    
    private func bottomCleanBar(result: DedupeScanResult) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Reclaimable Space")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(result.formattedReclaimableSize)
                    .font(.headline.bold())
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            Button {
                showingTrashConfirmation = true
            } label: {
                Label("Clean All Duplicates", systemImage: "trash.fill")
                    .font(.subheadline.bold())
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            Color.dedupeCardBackground
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: -2)
        )
    }
}
#endif
