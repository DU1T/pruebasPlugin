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

        updateUI {
            self.state.discoveredDevices[deviceId] = rssi
        }

        if _connectedDevices.count < connectionLimit {
            uwbManager?.connectTo(deviceID: deviceId)
        }
    }

    func didUpdatePosition(deviceId: String, distance: Double) {
        let anchor = getAnchor(deviceID: deviceId, distance: distance)
        _anchors[deviceId] = anchor

        let now = Date().timeIntervalSince1970
        _anchors = _anchors.filter { (_, a) in
            guard let timestamp = a.timestamp else { return true }
            return now - timestamp <= connectionTimeout
        }

        var newDistances: [String: Double] = [:]
        for (id, a) in _anchors {
            newDistances[id] = a.distance
        }

        var newFilteredPos: Vector2D? = nil
        if _anchors.count >= 3 {
            let position = do_trilateration(anchors: _anchors)
            KalmanFilter.shared.update(z: position.toSIMD())
            let filtered = KalmanFilter.shared.getX()
            newFilteredPos = Vector2D(x: filtered[0], y: filtered[1])
            print(String(describing: newFilteredPos))
        }

        updateUI {
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
