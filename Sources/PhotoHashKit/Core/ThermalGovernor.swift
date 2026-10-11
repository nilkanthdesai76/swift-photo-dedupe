import Foundation

/// Real-time thermal management governor that prevents device overheating during large photo scans.
/// Dynamically regulates worker thread count and inserts micro-pauses based on SoC thermal telemetry.
public final class ThermalGovernor: @unchecked Sendable {
    public static let shared = ThermalGovernor()
    
    public typealias ThermalStateChangeHandler = @Sendable (ProcessInfo.ThermalState) -> Void
    
    private let lock = NSLock()
    private var observers: [UUID: ThermalStateChangeHandler] = [:]
    
    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(thermalStateChanged),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func thermalStateChanged() {
        let current = thermalState
        lock.lock()
        let handlers = Array(observers.values)
        lock.unlock()
        
        for handler in handlers {
            handler(current)
        }
    }
    
    /// Current hardware thermal state reported by macOS / iOS kernel.
    public var thermalState: ProcessInfo.ThermalState {
        ProcessInfo.processInfo.thermalState
    }
    
    /// Recommended maximum concurrent operations to stay completely cool.
    public var recommendedConcurrency: Int {
        switch thermalState {
        case .nominal:
            // Cool state: max 2-3 workers, leaving other efficiency cores completely free
            return min(3, max(1, ProcessInfo.processInfo.activeProcessorCount / 2))
        case .fair:
            // Warming up: throttle down to 1-2 workers
            return 1
        case .serious:
            // Serious heat: strictly 1 worker
            return 1
        case .critical:
            // Critical heat: 1 worker with heavy pauses
            return 1
        @unknown default:
            return 2
        }
    }
    
    /// Pauses execution dynamically if the device shows any sign of thermal rise.
    public func applyThermalPacing() async {
        switch thermalState {
        case .nominal:
            // Zero pause needed, device is cold
            break
        case .fair:
            // Slight pause (8ms) between batches prevents thermal build-up
            try? await Task.sleep(nanoseconds: 8_000_000)
        case .serious:
            // Noticeable heat: sleep 80ms to allow fan/heatsink dissipation
            try? await Task.sleep(nanoseconds: 80_000_000)
        case .critical:
            // Dangerous heat: sleep 250ms and wait for cool-down
            try? await Task.sleep(nanoseconds: 250_000_000)
        @unknown default:
            break
        }
    }
    
    /// Human-readable description of current thermal posture.
    public var thermalStatusDescription: String {
        switch thermalState {
        case .nominal:
            return "Nominal (Cold / Optimal)"
        case .fair:
            return "Fair (Warm - Throttling 50%)"
        case .serious:
            return "Serious (Hot - Throttling 80%)"
        case .critical:
            return "Critical (Paused for Cool-down)"
        @unknown default:
            return "Normal"
        }
    }
    
    /// Register an observer to receive thermal state updates.
    @discardableResult
    public func addObserver(_ handler: @escaping ThermalStateChangeHandler) -> UUID {
        lock.lock()
        defer { lock.unlock() }
        let id = UUID()
        observers[id] = handler
        return id
    }
    
    /// Remove an observer.
    public func removeObserver(id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        observers.removeValue(forKey: id)
    }
}
