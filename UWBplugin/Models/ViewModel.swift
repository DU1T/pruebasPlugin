//
//  ViewModel.swift
//  UWBplugin
//
//  Created by Gustavo Gonzalez on 7/21/25.
//
import Foundation


/// Main view model responsible for initializing and coordinating all components of the UWB plugin.
///
/// The `ViewModel` sets up and links the `PositionCoordinator`, `AccelerometerManager`, and `UWBManager`.
/// It manages environment settings such as refresh rate, connection limits, and timeout durations.
/// This class serves as the central orchestrator that keeps the accelerometer and UWB data synchronized
/// through a shared operation queue.
class ViewModel{
    // these should be environment variables
    var mapURL = "casa.json"
    var refreshRate = Float(0.1)
    var connectionLimit = 100 // practically unlimited  
    var connectionTimout = 10.0
    let posCoordinator: PositionCoordinator
    
    var anchorMap: [String: Vector3D]
    

    /// Initializes the `ViewModel` with the given anchor positions.
    ///
    /// This constructor:
    /// - Stores the anchor map used for position calculation.
    /// - Creates a shared `OperationQueue` for both the accelerometer and UWB modules.
    /// - Initializes and starts the accelerometer and UWB managers.
    /// - Registers these managers as delegates in the `PositionCoordinator` to receive sensor updates.
    ///
    /// - Parameters:
    ///   - anchorMap: A dictionary mapping anchor IDs to their corresponding 3D coordinates.
    init(anchorMap: [String: Vector3D]){
        // The dictionary of Anchors is passed as a parameter
        self.anchorMap = anchorMap
        
        //We initialize a single operation queue for the Accelerometer and UWB modules
        let queue = OperationQueue()
        queue.name = "UWB and Accelerometer queue"
        queue.maxConcurrentOperationCount = 1
        
        posCoordinator = PositionCoordinator(anchorsPositions: anchorMap, connectionLimit: connectionLimit, connectionTimeout: connectionTimout)
        
        let accelerometerManager = AccelerometerManager(refreshRate: refreshRate, delegate: posCoordinator, accelerometerQueue: queue)
        let uwbManager = UWBManager(delegate: posCoordinator, UWBQueue: queue)
        uwbManager.startScanning()
        accelerometerManager.startListening()
        
        // IMPORTANT: add the delegates to the Position Coordinator
        posCoordinator.accelerometerManager = accelerometerManager
        posCoordinator.uwbManager = uwbManager
    }
    
    /// Returns the active instance of the `PositionCoordinator`.
    ///
    /// The `PositionCoordinator` is responsible for combining UWB distance data and accelerometer input
    /// to calculate a filtered user position.
    ///
    /// - Returns: The initialized `PositionCoordinator` instance used by this `ViewModel`.
    func getPositionCoordinator() -> PositionCoordinator{
        return self.posCoordinator
    }
}
