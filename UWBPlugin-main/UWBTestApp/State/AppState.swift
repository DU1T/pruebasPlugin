//
//  AppState.swift
//  UWBTestApp
//
import Foundation
import Observation

@Observable
class AppState {
    var mapSensors: [String] = []
    var discoveredDevices: [String: Double] = [:]  // deviceId → RSSI
    var connectedDevices: Set<String> = []
    var distances: [String: Double] = [:]           // deviceId → distance in meters
    var filteredPos: Vector2D? = nil

    // Distance filter settings (persist across map changes)
    var distanceFilterEnabled: Bool = false
    var maxConnectionDistance: Double = 5.0         // meters

    func reset() {
        mapSensors = []
        discoveredDevices = [:]
        connectedDevices = []
        distances = [:]
        filteredPos = nil
        // distanceFilterEnabled and maxConnectionDistance are user preferences — not reset
    }
}
