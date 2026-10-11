import SwiftUI
import PhotoHashKit

public struct GroupDetailView: View {
    public let group: DuplicateGroup
    
    public init(group: DuplicateGroup) {
        self.group = group
    }
    
    private var categoryColor: Color {
        switch group.category {
        case .exactDuplicate: return .green
        case .nearDuplicate: return .yellow
        case .similar: return .blue
        case .different: return .gray
        }
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header Banner
            HStack(alignment: .center, spacing: 12) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(categoryColor)
                        .frame(width: 8, height: 8)
                    Text(group.category.rawValue)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(categoryColor)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(categoryColor.opacity(0.12))
                .clipShape(Capsule())
                
                Text("\(String(format: "%.1f", group.similarityScore))% Match")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("RECLAIMABLE SPACE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                    Text(group.formattedReclaimableSize)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green)
                }
            }
            .padding()
            .background(Color.primary.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            Divider()
            
            // Assets Grid / Cards
            ScrollView(.vertical, showsIndicators: true) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 16)], spacing: 16) {
                    ForEach(group.assets) { asset in
                        let isKeeper = asset.id == group.bestAssetId
                        
                        VStack(alignment: .leading, spacing: 10) {
                            // Thumbnail placeholder / preview
                            ZStack(alignment: .topTrailing) {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.primary.opacity(0.06))
                                    .frame(height: 160)
                                    .overlay(
                                        VStack(spacing: 8) {
                                            Image(systemName: "photo")
                                                .font(.system(size: 36))
                                                .foregroundStyle(.secondary.opacity(0.6))
                                            Text(asset.filename)
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    )
                                
                                // Keeper badge
                                if isKeeper {
                                    HStack(spacing: 4) {
                                        Image(systemName: "star.fill")
                                        Text("KEEPER")
                                    }
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.yellow)
                                    .clipShape(Capsule())
                                    .padding(8)
                                    .shadow(radius: 4)
                                } else {
                                    HStack(spacing: 4) {
                                        Image(systemName: "trash")
                                        Text("RECLAIM")
                                    }
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.red)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.red.opacity(0.12))
                                    .clipShape(Capsule())
                                    .padding(8)
                                }
                            }
                            
                            // Metadata Details
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(asset.filename)
                                        .font(.system(size: 12, weight: .bold))
                                        .lineLimit(1)
                                    Spacer()
                                    Text(asset.formattedSize)
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                                
                                Text("\(asset.pixelWidth) × \(asset.pixelHeight) px")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                
                                if let hash = asset.dualHash {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("dHash: 0x\(hash.dHashHex)")
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                        Text("pHash: 0x\(hash.pHashHex)")
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                        
                                        if let keeperHash = group.keeper?.dualHash, !isKeeper {
                                            let dDist = hash.dDistance(to: keeperHash)
                                            let pDist = hash.pDistance(to: keeperHash)
                                            Text("Δ dDist: \(dDist) bits • pDist: \(pDist) bits")
                                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                                .foregroundStyle(categoryColor)
                                                .padding(.top, 2)
                                        }
                                    }
                                    .padding(6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.primary.opacity(0.03))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isKeeper ? Color.yellow.opacity(0.04) : Color.primary.opacity(0.02))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isKeeper ? Color.yellow.opacity(0.4) : Color.primary.opacity(0.08), lineWidth: isKeeper ? 1.5 : 1)
                                )
                        )
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
    }
}
