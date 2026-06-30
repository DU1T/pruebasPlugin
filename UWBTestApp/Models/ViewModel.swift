//
//  ViewModel.swift
//  UWBplugin
//
//  Created by Gustavo Gonzalez on 7/21/25.
//
import Foundation
import Observation

@Observable
class ViewModel {
    let state = AppState()
    let availableMaps = ["casa.json", "campus4sensors.json", "campusTest.json", "315b.json"]
    var selectedMap: String = "casa.json"

    private let connectionLimit = 100
    private let connectionTimeout = 10.0
    private let refreshRate: Float = 0.1

    private var positionCoordinator: PositionCoordinator?
    private var uwbManager: UWBManager?
    private var accelerometerManager: AccelerometerManager?
    private var queue: OperationQueue?
    private var isStarted = false

    // Empty init — initialization is deferred to startIfNeeded() so the
    // main thread is not blocked before the first frame renders.
    init() {}

    /// Called once after the first frame renders. Safe to call multiple times.
    func startIfNeeded() {
        guard !isStarted else { return }
        isStarted = true
        start(map: selectedMap)
    }

    func changeMap(_ map: String) {
        guard map != selectedMap else { return }
        selectedMap = map
        stop()
        state.reset()
        start(map: map)
    }

    private func start(map: String) {
        let anchorMap = MapReader.readCoordinates(from: map)

        let q = OperationQueue()
        q.name = "UWB and Accelerometer queue"
        q.maxConcurrentOperationCount = 1
        self.queue = q

        let coordinator = PositionCoordinator(
            state: state,
            anchorsPositions: anchorMap,
            connectionLimit: connectionLimit,
            connectionTimeout: connectionTimeout
        )

        let accel = AccelerometerManager(refreshRate: refreshRate, delegate: coordinator, accelerometerQueue: q)
        let uwb = UWBManager(delegate: coordinator, UWBQueue: q)

        coordinator.uwbManager = uwb
        coordinator.accelerometerManager = accel

        uwb.startScanning()
        accel.startListening()

        self.positionCoordinator = coordinator
        self.uwbManager = uwb
        self.accelerometerManager = accel

        DispatchQueue.main.async {
            self.state.mapSensors = Array(anchorMap.keys)
        }
    }

    private func stop() {
        uwbManager?.stopScanning()
        accelerometerManager?.stopListening()
        positionCoordinator = nil
        uwbManager = nil
        accelerometerManager = nil
        queue = nil
    }
}
