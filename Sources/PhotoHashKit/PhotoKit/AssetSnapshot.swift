import Foundation
import CoreGraphics

#if canImport(AppKit)
import AppKit
public typealias PlatformImage = NSImage
#elseif canImport(UIKit)
import UIKit
public typealias PlatformImage = UIImage
#endif

/// Lightweight, thread-safe representation of a photo asset.
public struct AssetSnapshot: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let filename: String
    public let creationDate: Date
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let fileSize: Int64
    public let isFavorite: Bool
    public let isLocallyAvailable: Bool
    public let dualHash: DualHash?
    
    public init(
        id: String,
        filename: String,
        creationDate: Date = Date(),
        pixelWidth: Int,
        pixelHeight: Int,
        fileSize: Int64,
        isFavorite: Bool = false,
        isLocallyAvailable: Bool = true,
        dualHash: DualHash? = nil
    ) {
        self.id = id
        self.filename = filename
        self.creationDate = creationDate
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.fileSize = fileSize
        self.isFavorite = isFavorite
        self.isLocallyAvailable = isLocallyAvailable
        self.dualHash = dualHash
    }
    
    public var totalPixels: Int {
        pixelWidth * pixelHeight
    }
    
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    public func withHash(_ hash: DualHash) -> AssetSnapshot {
        AssetSnapshot(
            id: id,
            filename: filename,
            creationDate: creationDate,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            fileSize: fileSize,
            isFavorite: isFavorite,
            isLocallyAvailable: isLocallyAvailable,
            dualHash: hash
        )
    }
}
