import Foundation
import CoreGraphics

/// Procedural sample image generator for instant verification, automated testing, and zero-dependency benchmarks.
public enum SampleImageGenerator {
    
    /// Generates a synthetic CGImage with specific visual shapes and colors.
    public static func generateTestImage(
        width: Int = 256,
        height: Int = 256,
        baseColor: (r: CGFloat, g: CGFloat, b: CGFloat),
        shapeOffset: CGPoint = .zero,
        pattern: Int = 0,
        addNoise: Bool = false
    ) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        
        let w = CGFloat(width)
        let h = CGFloat(height)
        
        // 1. Natural Background Gradient (mimics realistic natural lighting / sky variations)
        let endR = max(0.0, baseColor.r * 0.75 + 0.05)
        let endG = max(0.0, baseColor.g * 0.75 + 0.05)
        let endB = max(0.0, baseColor.b * 0.75 + 0.05)
        let colors = [
            CGColor(red: baseColor.r, green: baseColor.g, blue: baseColor.b, alpha: 1.0),
            CGColor(red: endR, green: endG, blue: endB, alpha: 1.0)
        ] as CFArray
        let colorLocations: [CGFloat] = [0.0, 1.0]
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: colorLocations) {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: w, y: h),
                options: []
            )
        } else {
            context.setFillColor(red: baseColor.r, green: baseColor.g, blue: baseColor.b, alpha: 1.0)
            context.fill(CGRect(x: 0, y: 0, width: w, height: h))
        }
        
        // 2. Pattern based geometry with offset support
        let ox = shapeOffset.x
        let oy = shapeOffset.y
        
        switch pattern % 8 {
        case 0:
            // Circle + diagonal stripe
            let circleRect = CGRect(x: w * 0.25 + ox, y: h * 0.25 + oy, width: w * 0.5, height: h * 0.5)
            context.setFillColor(red: 1.0 - baseColor.r, green: 1.0 - baseColor.g, blue: 0.2, alpha: 1.0)
            context.fillEllipse(in: circleRect)
            context.setStrokeColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)
            context.setLineWidth(12.0)
            context.move(to: CGPoint(x: ox, y: oy))
            context.addLine(to: CGPoint(x: w + ox, y: h + oy))
            context.strokePath()
            
        case 1:
            // Vertical Bars
            context.setFillColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)
            for x in stride(from: 0, to: Int(w), by: 32) {
                context.fill(CGRect(x: CGFloat(x) + ox, y: oy, width: 16, height: h))
            }
            
        case 2:
            // Horizontal Bands
            context.setFillColor(red: 0.1, green: 0.1, blue: 0.9, alpha: 1.0)
            for y in stride(from: 0, to: Int(h), by: 32) {
                context.fill(CGRect(x: ox, y: CGFloat(y) + oy, width: w, height: 16))
            }
            
        case 3:
            // Off-center Square + accent circle
            context.setFillColor(red: 0.95, green: 0.2, blue: 0.8, alpha: 1.0)
            context.fill(CGRect(x: w * 0.2 + ox, y: h * 0.25 + oy, width: w * 0.55, height: h * 0.5))
            context.setFillColor(red: 0.2, green: 0.9, blue: 0.7, alpha: 0.8)
            context.fillEllipse(in: CGRect(x: w * 0.6 + ox, y: h * 0.15 + oy, width: w * 0.25, height: w * 0.25))
            
        case 4:
            // Cross
            context.setFillColor(red: 0.2, green: 0.85, blue: 0.3, alpha: 1.0)
            context.fill(CGRect(x: w * 0.4 + ox, y: oy, width: w * 0.2, height: h))
            context.fill(CGRect(x: ox, y: h * 0.4 + oy, width: w, height: h * 0.2))
            
        case 5:
            // Star/Diamond
            context.setFillColor(red: 0.9, green: 0.5, blue: 0.1, alpha: 1.0)
            context.move(to: CGPoint(x: w * 0.5 + ox, y: 0 + oy))
            context.addLine(to: CGPoint(x: w + ox, y: h * 0.5 + oy))
            context.addLine(to: CGPoint(x: w * 0.5 + ox, y: h + oy))
            context.addLine(to: CGPoint(x: 0 + ox, y: h * 0.5 + oy))
            context.closePath()
            context.fillPath()
            
        case 6:
            // Corner Triangles
            context.setFillColor(red: 0.1, green: 0.9, blue: 0.9, alpha: 1.0)
            context.fill(CGRect(x: ox, y: oy, width: w * 0.4, height: h * 0.4))
            context.fill(CGRect(x: w * 0.6 + ox, y: h * 0.6 + oy, width: w * 0.4, height: h * 0.4))
            
        default:
            // Checkerboard grid
            context.setFillColor(red: 0.8, green: 0.8, blue: 0.1, alpha: 1.0)
            for y in stride(from: 0, to: Int(h), by: 64) {
                for x in stride(from: 0, to: Int(w), by: 64) {
                    context.fill(CGRect(x: CGFloat(x) + ox, y: CGFloat(y) + oy, width: 32, height: 32))
                }
            }
        }
        
        // 3. Optional Compression / Re-encode Simulation (WhatsApp / AirDrop)
        if addNoise {
            // Subtle high-frequency compression wash without destroying structural energy
            context.setFillColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 0.06)
            context.fill(CGRect(x: 0, y: 0, width: w, height: h * 0.4))
            for i in 0..<16 {
                let rx = CGFloat((i * 17) % Int(w))
                let ry = CGFloat((i * 23) % Int(h))
                context.fill(CGRect(x: rx, y: ry, width: 3, height: 3))
            }
        }
        
        return context.makeImage()
    }
    
    /// Generates a realistic synthetic dataset containing:
    /// - 3 Exact Duplicates (Cluster 1)
    /// - 2 Near Duplicates / Recompressed (Cluster 2)
    /// - 4 Similar Burst Shots (Cluster 3)
    /// - 8 Distinct Unique Non-Duplicates
    public static func createBenchmarkDataset() -> [AssetSnapshot] {
        var snapshots: [AssetSnapshot] = []
        
        // --- Cluster 1: Exact Duplicates (Landscape Scene) ---
        if let baseImg1 = generateTestImage(baseColor: (r: 0.2, g: 0.6, b: 0.8), pattern: 0) {
            let hash1 = DualHash.compute(from: baseImg1)!
            snapshots.append(AssetSnapshot(id: "exact-1a", filename: "IMG_1001.JPG", pixelWidth: 4032, pixelHeight: 3024, fileSize: 4_200_000, dualHash: hash1))
            snapshots.append(AssetSnapshot(id: "exact-1b", filename: "IMG_1001_copy.JPG", pixelWidth: 4032, pixelHeight: 3024, fileSize: 4_200_000, dualHash: hash1))
            snapshots.append(AssetSnapshot(id: "exact-1c", filename: "IMG_1001 (1).JPG", pixelWidth: 4032, pixelHeight: 3024, fileSize: 4_198_000, dualHash: hash1))
        }
        
        // --- Cluster 2: Near Duplicates (WhatsApp / Recompressed Sunset) ---
        if let baseImg2 = generateTestImage(baseColor: (r: 0.85, g: 0.35, b: 0.15), pattern: 3),
           let compressedImg2 = generateTestImage(baseColor: (r: 0.85, g: 0.35, b: 0.15), pattern: 3, addNoise: true) {
            let hash2a = DualHash.compute(from: baseImg2)!
            let hash2b = DualHash.compute(from: compressedImg2)!
            snapshots.append(AssetSnapshot(id: "near-2a", filename: "Sunset_Original.HEIC", pixelWidth: 4032, pixelHeight: 3024, fileSize: 3_800_000, dualHash: hash2a))
            snapshots.append(AssetSnapshot(id: "near-2b", filename: "Sunset_WhatsApp.jpeg", pixelWidth: 1600, pixelHeight: 1200, fileSize: 340_000, dualHash: hash2b))
        }
        
        // --- Cluster 3: Burst Shots (Subject Movement Across Frames) ---
        let burstOffsets: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 3, y: 2),
            CGPoint(x: 6, y: 4),
            CGPoint(x: 9, y: 6)
        ]
        for (idx, offset) in burstOffsets.enumerated() {
            if let burstImg = generateTestImage(baseColor: (r: 0.25, g: 0.75, b: 0.45), shapeOffset: offset, pattern: 5) {
                let hash = DualHash.compute(from: burstImg)!
                snapshots.append(AssetSnapshot(id: "burst-3\(idx)", filename: "BURST_20261011_\(idx).HEIC", pixelWidth: 4032, pixelHeight: 3024, fileSize: 3_500_000, dualHash: hash))
            }
        }
        
        // --- Distinct Unique Photos (No duplicates) ---
        let uniqueConfigs: [(r: CGFloat, g: CGFloat, b: CGFloat, pat: Int)] = [
            (0.12, 0.15, 0.22, 1),
            (0.92, 0.88, 0.12, 2),
            (0.48, 0.12, 0.78, 4),
            (0.15, 0.85, 0.88, 6),
            (0.88, 0.45, 0.12, 7),
            (0.35, 0.35, 0.38, 1),
            (0.78, 0.15, 0.52, 2),
            (0.18, 0.22, 0.68, 6)
        ]
        for (idx, cfg) in uniqueConfigs.enumerated() {
            if let uniqueImg = generateTestImage(baseColor: (r: cfg.r, g: cfg.g, b: cfg.b), pattern: cfg.pat) {
                let hash = DualHash.compute(from: uniqueImg)!
                snapshots.append(AssetSnapshot(id: "unique-\(idx)", filename: "DSC_\(2000 + idx).JPG", pixelWidth: 3840, pixelHeight: 2160, fileSize: 2_900_000, dualHash: hash))
            }
        }
        
        return snapshots
    }
}
