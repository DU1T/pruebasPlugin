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
    var lastTime = Date().timeIntervalSince1970

    var anchorsPositions: [String: Vector3D]
    var connectionLimit: Int
    var connectionTimeout: Double

    var uwbManager: UWBManager?
    var accelerometerManager: AccelerometerManager?

    // Distance filter: tracks when each sensor was disconnected for being out of range
    // Key: deviceId, Value: timestamp of disconnection
    private var distanceCooldowns: [String: TimeInterval] = [:]
    private let reconnectCooldown: Double = 5.0

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

    func didDisconnect(deviceId: String) {
        _connectedDevices.remove(deviceId)
        _anchors.removeValue(forKey: deviceId)
        updateUI {
            self.state.connectedDevices.remove(deviceId)
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

        // Check distance cooldown: if the sensor was recently disconnected for being
        // out of range, wait before attempting to reconnect
        if let cooldownStart = distanceCooldowns[deviceId] {
            let elapsed = Date().timeIntervalSince1970 - cooldownStart
            if elapsed < reconnectCooldown {
                return  // still in cooldown, update RSSI but don't reconnect
            }
            distanceCooldowns.removeValue(forKey: deviceId)
        }

        updateUI {
            self.state.discoveredDevices[deviceId] = rssi
        }

        if _connectedDevices.count < connectionLimit {
            uwbManager?.connectTo(deviceID: deviceId)
        }
    }

    func didUpdatePosition(deviceId: String, distance: Double) {
        // 1. Distance filter: if enabled and sensor is beyond threshold, disconnect it
        if state.distanceFilterEnabled && distance > state.maxConnectionDistance {
            distanceCooldowns[deviceId] = Date().timeIntervalSince1970
            uwbManager?.disconnectFrom(deviceId: deviceId)
            _anchors.removeValue(forKey: deviceId)
            _connectedDevices.remove(deviceId)
            updateUI {
                self.state.connectedDevices.remove(deviceId)
                self.state.distances.removeValue(forKey: deviceId)
            }
            print("Sensor \(deviceId.suffix(8)) out of range (\(String(format: "%.2f", distance))m > \(self.state.maxConnectionDistance)m), disconnecting")
            return
        }

        // 2. Update anchor with new distance reading
        _anchors[deviceId] = getAnchor(deviceID: deviceId, distance: distance)

        // 3. Remove expired anchors AND sync _connectedDevices for those that timed out
        //    This covers the case where didDisconnect was never called (abrupt power-off)
        let now = Date().timeIntervalSince1970
        var expiredIds: [String] = []
        _anchors = _anchors.filter { (id, a) in
            guard let ts = a.timestamp else { return true }
            let active = now - ts <= connectionTimeout
            if !active { expiredIds.append(id) }
            return active
        }
        for id in expiredIds {
            _connectedDevices.remove(id)
        }

        // 4. Build current distances from all active anchors
        var newDistances: [String: Double] = [:]
        for (id, a) in _anchors {
            newDistances[id] = a.distance
        }

        // 5. Trilateration + Kalman filter
        var newFilteredPos: Vector2D? = nil
        if _anchors.count >= 3 {
            let position = do_trilateration(anchors: _anchors)
            KalmanFilter.shared.update(z: position.toSIMD())
            let filtered = KalmanFilter.shared.getX()
            newFilteredPos = Vector2D(x: filtered[0], y: filtered[1])
            print(String(describing: newFilteredPos))
        }

        // 6. Push all UI updates atomically on the main thread
        let expiredIdsForUI = expiredIds
        updateUI {
            for id in expiredIdsForUI {
                self.state.connectedDevices.remove(id)
                self.state.distances.removeValue(forKey: id)
            }
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
