import Foundation
import CoreGraphics
import Accelerate

/// High-performance, hardware-accelerated image scaling and DCT operations.
/// Operates on minimal thumbnail buffers to avoid memory spikes and thermal heating.
public enum AccelerateImageOps {
    
    // MARK: - Precomputed 2D DCT Cosine Matrix (32x32)
    
    private static let dctMatrix: [Float] = {
        var matrix = [Float](repeating: 0, count: 32 * 32)
        let n: Float = 32.0
        let invSqrtN = 1.0 / sqrt(n)
        let sqrtTwoOverN = sqrt(2.0 / n)
        
        for u in 0..<32 {
            let alpha: Float = (u == 0) ? invSqrtN : sqrtTwoOverN
            for x in 0..<32 {
                let angle = (Float(2 * x + 1) * Float(u) * Float.pi) / (2.0 * n)
                matrix[u * 32 + x] = alpha * cos(angle)
            }
        }
        return matrix
    }()
    
    private static let dctMatrixTransposed: [Float] = {
        var transposed = [Float](repeating: 0, count: 32 * 32)
        for r in 0..<32 {
            for c in 0..<32 {
                transposed[r * 32 + c] = dctMatrix[c * 32 + r]
            }
        }
        return transposed
    }()
    
    // MARK: - Grayscale Thumbnail Resizing
    
    /// Downscales an input CGImage to an exact target width and height in 8-bit grayscale.
    /// Returns raw pixel bytes of length `width * height`.
    public static func renderGrayscale(
        from cgImage: CGImage,
        width: Int,
        height: Int
    ) -> [UInt8]? {
        let totalBytes = width * height
        var pixels = [UInt8](repeating: 0, count: totalBytes)
        
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }
        
        context.interpolationQuality = .medium
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.draw(cgImage, in: rect)
        
        return pixels
    }
    
    // MARK: - Fast 2D DCT (32x32 -> 8x8 Low Frequencies)
    
    /// Computes the 2D Discrete Cosine Transform on a 32x32 grayscale image buffer.
    /// Returns the top-left 8x8 low-frequency coefficients (64 values).
    public static func compute8x8DCT(from grayscale32x32: [UInt8]) -> [Float] {
        precondition(grayscale32x32.count == 32 * 32, "Input buffer must be exactly 32x32 pixels")
        
        // Convert UInt8 to Float (0.0 ... 255.0)
        var inputFloats = [Float](repeating: 0, count: 1024)
        for i in 0..<1024 {
            inputFloats[i] = Float(grayscale32x32[i])
        }
        
        // 2D DCT is separable: Output = D * Input * D^T
        // Step 1: Intermediate = D * Input (32x32 matrix multiplication)
        var intermediate = [Float](repeating: 0, count: 1024)
        vDSP_mmul(
            dctMatrix, 1,
            inputFloats, 1,
            &intermediate, 1,
            32, 32, 32
        )
        
        // Step 2: Output = Intermediate * D^T
        var fullDCT = [Float](repeating: 0, count: 1024)
        vDSP_mmul(
            intermediate, 1,
            dctMatrixTransposed, 1,
            &fullDCT, 1,
            32, 32, 32
        )
        
        // Step 3: Extract top-left 8x8 matrix (lowest 64 frequencies)
        var result = [Float](repeating: 0, count: 64)
        for u in 0..<8 {
            for v in 0..<8 {
                result[u * 8 + v] = fullDCT[u * 32 + v]
            }
        }
        
        return result
    }
}
