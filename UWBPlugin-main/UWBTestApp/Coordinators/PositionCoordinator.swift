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
    // This prevents rapid in/out toggling when a sensor sits right at the boundary.
    private let hysteresisRatio: Double = 0.85

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
        // 1. Update anchor with latest distance (always, regardless of filter)
        _anchors[deviceId] = getAnchor(deviceID: deviceId, distance: distance)

        // 2. Distance filter with hysteresis — operates on data, never on the connection.
        //    Sensors stay connected so the UWB session remains alive.
        //    Hysteresis prevents rapid toggling when a sensor sits right at the boundary:
        //      - Excluded → re-included only when distance drops to 85% of threshold
        //      - Included → excluded when distance exceeds threshold
        if state.distanceFilterEnabled {
            let threshold = state.maxConnectionDistance
            if _outOfRangeDevices.contains(deviceId) {
                // Currently excluded: re-include only when clearly within range
                if distance <= threshold * hysteresisRatio {
                    _outOfRangeDevices.remove(deviceId)
                    print("Sensor \(deviceId.suffix(8)) back in range (\(String(format: "%.2f", distance))m)")
                }
            } else {
                // Currently included: exclude when beyond threshold
                if distance > threshold {
                    _outOfRangeDevices.insert(deviceId)
                    print("Sensor \(deviceId.suffix(8)) out of range (\(String(format: "%.2f", distance))m > \(threshold)m)")
                }
            }
        } else {
            // Filter disabled: ensure nothing is excluded
            _outOfRangeDevices.remove(deviceId)
        }

        // 3. Remove expired anchors and sync _connectedDevices for those that timed out.
        //    Covers abrupt power-off where didDisconnect is never called.
        let now = Date().timeIntervalSince1970
        var expiredIds: [String] = []
        _anchors = _anchors.filter { (id, a) in
            guard let ts = a.timestamp else { return true }
            let active = now - ts <= connectionTimeout
            if !active {
                expiredIds.append(id)
            }
            return active
        }
        for id in expiredIds {
            _connectedDevices.remove(id)
            _outOfRangeDevices.remove(id)
        }

        // 4. Trilateration uses only in-range anchors
        let activeAnchors = _anchors.filter { !_outOfRangeDevices.contains($0.key) }

        // 5. Distances reported for all connected sensors (in and out of range)
        var newDistances: [String: Double] = [:]
        for (id, a) in _anchors {
            newDistances[id] = a.distance
        }

        // 6. Compute position with in-range anchors only
        var newFilteredPos: Vector2D? = nil
        if activeAnchors.count >= 3 {
            let position = do_trilateration(anchors: activeAnchors)
            KalmanFilter.shared.update(z: position.toSIMD())
            let filtered = KalmanFilter.shared.getX()
            newFilteredPos = Vector2D(x: filtered[0], y: filtered[1])
            print(String(describing: newFilteredPos))
        }

        // 7. Push all UI updates to the main thread
        let expiredIdsForUI = expiredIds
        let outOfRangeSnapshot = _outOfRangeDevices
        updateUI {
            for id in expiredIdsForUI {
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
