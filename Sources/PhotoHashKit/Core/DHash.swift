import Foundation
import CoreGraphics

/// Difference Hash (dHash) generator.
/// Resizes image to 9x8 grayscale (72 pixels) and inspects adjacent horizontal gradients.
/// Extremely lightweight and resilient to brightness variations and aspect scaling.
public enum DHash {
    
    /// Computes a 64-bit dHash from a CGImage.
    /// Returns nil if image cannot be rendered into a grayscale buffer.
    public static func compute(from cgImage: CGImage) -> UInt64? {
        guard let pixels = AccelerateImageOps.renderGrayscale(from: cgImage, width: 9, height: 8) else {
            return nil
        }
        return compute(fromGrayscale9x8: pixels)
    }
    
    /// Computes a 64-bit dHash directly from a pre-rendered 9x8 (72-byte) grayscale buffer.
    public static func compute(fromGrayscale9x8 pixels: [UInt8]) -> UInt64 {
        precondition(pixels.count == 72, "dHash requires exactly 9x8 = 72 bytes")
        
        var hash: UInt64 = 0
        var bitIndex: UInt64 = 0
        
        for y in 0..<8 {
            let rowOffset = y * 9
            for x in 0..<8 {
                let left = pixels[rowOffset + x]
                let right = pixels[rowOffset + x + 1]
                
                if left > right {
                    hash |= (1 << bitIndex)
                }
                bitIndex += 1
            }
        }
        
        return hash
    }
    
    /// Computes the Hamming distance between two 64-bit dHashes.
    /// Takes a single CPU popcount instruction (< 1 nanosecond).
    @inlinable
    public static func distance(_ hash1: UInt64, _ hash2: UInt64) -> Int {
        (hash1 ^ hash2).nonzeroBitCount
    }
}
