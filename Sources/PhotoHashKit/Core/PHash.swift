import Foundation
import CoreGraphics

/// Perceptual Hash (pHash) generator.
/// Resizes image to 32x32 grayscale (1024 pixels), executes 2D DCT, extracts top-left 8x8 low frequencies,
/// and builds a 64-bit fingerprint against the median frequency.
/// Highly resilient to gamma changes, filters, compression artifacts, and minor crops.
public enum PHash {
    
    /// Computes a 64-bit pHash from a CGImage.
    public static func compute(from cgImage: CGImage) -> UInt64? {
        guard let pixels = AccelerateImageOps.renderGrayscale(from: cgImage, width: 32, height: 32) else {
            return nil
        }
        return compute(fromGrayscale32x32: pixels)
    }
    
    /// Computes a 64-bit pHash from a pre-rendered 32x32 (1024-byte) grayscale buffer.
    public static func compute(fromGrayscale32x32 pixels: [UInt8]) -> UInt64 {
        precondition(pixels.count == 1024, "pHash requires exactly 32x32 = 1024 bytes")
        
        // 1. Compute 8x8 low-frequency DCT matrix
        let dct8x8 = AccelerateImageOps.compute8x8DCT(from: pixels)
        
        // 2. Compute the median of the 64 low frequencies (excluding DC component at index 0 for brightness immunity)
        // Using all 63 AC frequencies gives true perceptual stability
        var acValues = Array(dct8x8[1..<64])
        acValues.sort()
        let median = acValues[acValues.count / 2]
        
        // 3. Set bits: 1 if coefficient > median, else 0
        var hash: UInt64 = 0
        for i in 0..<64 {
            if dct8x8[i] > median {
                hash |= (1 << UInt64(i))
            }
        }
        
        return hash
    }
    
    /// Computes the Hamming distance between two 64-bit pHashes.
    /// Takes a single CPU popcount instruction (< 1 nanosecond).
    @inlinable
    public static func distance(_ hash1: UInt64, _ hash2: UInt64) -> Int {
        (hash1 ^ hash2).nonzeroBitCount
    }
}
