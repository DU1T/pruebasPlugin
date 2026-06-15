//
//  PositionCoordinator.swift
//  UWBplugin
//
//  Created by Gustavo Gonzalez on 7/20/25.
//

import Foundation

class PositionCoordinator {
    private let state: AppState

    // Internal computation state — only accessed on the serial OperationQueue
    private var _connectedDevices: Set<String> = []
    private var _anchors: [String: Anchor] = [:]
    private var _outOfRangeDevices: Set<String> = []
    var lastTime = Date().timeIntervalSince1970

    var anchorsPositions: [String: Vector3D]
    var connectionLimit: Int
    var connectionTimeout: Double

    var uwbManager: UWBManager?
    var accelerometerManager: AccelerometerManager?

    // Hysteresis: sensor re-enters computation at 85% of the exclusion threshold.
    private let hysteresisRatio: Double = 0.85

    // UI throttle: distance/position updates are batched and pushed at most 8 times/second.
    // Connection events (connect/disconnect) bypass the throttle and push immediately.
    // pendingExpiredIds accumulates sensors that timed out between throttled pushes so
    // they are not lost if no further update arrives before the next push window.
    private var lastUIUpdate: TimeInterval = 0
    private let uiUpdateInterval: TimeInterval = 1.0 / 8.0  // 125ms → 8Hz max
    private var pendingExpiredIds: [String] = []

    init(state: AppState, anchorsPositions: [String: Vector3D], connectionLimit: Int, connectionTimeout: Double) {
        self.state = state
        self.anchorsPositions = anchorsPositions
        self.connectionLimit = connectionLimit
        self.connectionTimeout = connectionTimeout
    }

    func getFilteredPosition() -> Vector2D? {
        return state.filteredPos
    }

    private func updateUI(_ block: @escaping () -> Void) {
        DispatchQueue.main.async(execute: block)
    }

    private func getAnchor(deviceID: String, distance: Double) -> Anchor {
        return Anchor(
            id: deviceID,
            position: anchorsPositions[deviceID]!,
            distance: distance,
            timestamp: Date().timeIntervalSince1970
        )
    }
}

extension PositionCoordinator: UWBManagerDelegate {

    // Connection events bypass the throttle — they are rare and must reflect immediately.

    func didDisconnect(deviceId: String) {
        _connectedDevices.remove(deviceId)
        _anchors.removeValue(forKey: deviceId)
        _outOfRangeDevices.remove(deviceId)
        updateUI {
            self.state.connectedDevices.remove(deviceId)
            self.state.outOfRangeDevices.remove(deviceId)
            self.state.distances.removeValue(forKey: deviceId)
        }
    }

    func didConnect(deviceId: String) {
        _connectedDevices.insert(deviceId)
        updateUI {
            self.state.connectedDevices.insert(deviceId)
        }
        print("Connected to device \(deviceId)")
    }

    func onDeviceDiscovered(deviceId: String, rssi: Double) {
        print("Discovered device \(deviceId)")

        guard anchorsPositions.keys.contains(deviceId) else { return }

        updateUI {
            self.state.discoveredDevices[deviceId] = rssi
        }

        if _connectedDevices.count < connectionLimit {
            uwbManager?.connectTo(deviceID: deviceId)
        }
    }

    func didUpdatePosition(deviceId: String, distance: Double) {
        // 1. Update anchor
        _anchors[deviceId] = getAnchor(deviceID: deviceId, distance: distance)

        // 2. Distance filter with hysteresis
        if state.distanceFilterEnabled {
            let threshold = state.maxConnectionDistance
            if _outOfRangeDevices.contains(deviceId) {
                if distance <= threshold * hysteresisRatio {
                    _outOfRangeDevices.remove(deviceId)
                }
            } else {
                if distance > threshold {
                    _outOfRangeDevices.insert(deviceId)
                }
            }
        } else {
            _outOfRangeDevices.remove(deviceId)
        }

        // 3. Expire anchors that haven't reported within connectionTimeout.
        //    Sync _connectedDevices so it doesn't diverge from _anchors.
        let now = Date().timeIntervalSince1970
        _anchors = _anchors.filter { (id, a) in
            guard let ts = a.timestamp else { return true }
            let active = now - ts <= connectionTimeout
            if !active {
                _connectedDevices.remove(id)
                _outOfRangeDevices.remove(id)
                pendingExpiredIds.append(id)
            }
            return active
        }

        // 4. Throttle: only push to the main thread at most every 125ms (8Hz).
        //    Expired IDs are accumulated so they are never silently dropped.
        guard now - lastUIUpdate >= uiUpdateInterval else { return }
        lastUIUpdate = now

        // 5. Capture state for the closure (OperationQueue → main thread boundary)
        let expiredToClean = pendingExpiredIds
        pendingExpiredIds = []

        var newDistances: [String: Double] = [:]
        for (id, a) in _anchors { newDistances[id] = a.distance }

        var newFilteredPos: Vector2D? = nil
        let activeAnchors = _anchors.filter { !_outOfRangeDevices.contains($0.key) }
        if activeAnchors.count >= 3 {
            let position = do_trilateration(anchors: activeAnchors)
            KalmanFilter.shared.update(z: position.toSIMD())
            let filtered = KalmanFilter.shared.getX()
            newFilteredPos = Vector2D(x: filtered[0], y: filtered[1])
        }

        let outOfRangeSnapshot = _outOfRangeDevices

        // 6. Single batched main-thread update
        updateUI {
            for id in expiredToClean {
                self.state.connectedDevices.remove(id)
                self.state.outOfRangeDevices.remove(id)
                self.state.distances.removeValue(forKey: id)
            }
            self.state.outOfRangeDevices = outOfRangeSnapshot
            self.state.distances = newDistances
            self.state.filteredPos = newFilteredPos
        }
    }
}

extension PositionCoordinator: AccelerometerDelegate {
    func onUpdate(vector: Vector2D) {
        let currentTime = Date().timeIntervalSince1970
        let deltaTime = currentTime - lastTime

        if KalmanFilter.shared.getX() == .zero {
            return
        }

        let simd2d = vector.toSIMD()

        KalmanFilter.shared.updateG(delta_time: deltaTime)
        KalmanFilter.shared.updateF(delta_time: deltaTime)
        KalmanFilter.shared.updateU(simd2d)
        KalmanFilter.shared.predict()

        lastTime = currentTime
    }
}
