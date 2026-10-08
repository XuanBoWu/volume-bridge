import Foundation

// Keep the user's current drag ahead of asynchronously published audio snapshots.
struct VolumeSliderState {
    private(set) var deviceUID = ""
    private(set) var isTracking = false
    private(set) var value: Double = 50
    private(set) var pendingValue: Double?

    mutating func beginTracking() { isTracking = true }
    mutating func endTracking() { isTracking = false }
    mutating func discardPending() { pendingValue = nil }

    mutating func userChanged(to newValue: Double) {
        // Match the Float sent to Core Audio so acknowledgements compare reliably.
        value = Double(Float(min(100, max(0, newValue))))
        pendingValue = value
    }

    mutating func refresh(volume: Double, uid: String, enabled: Bool) {
        let changedDevice = uid != deviceUID
        if changedDevice || !enabled { pendingValue = nil }
        deviceUID = uid
        if let pending = pendingValue, abs(pending - volume) < 0.0001 {
            pendingValue = nil
        }
        if isTracking && enabled && !changedDevice { return }
        value = pendingValue ?? volume
    }
}
