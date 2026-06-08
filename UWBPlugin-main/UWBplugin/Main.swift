//
//  Main.swift
//  UWBplugin
//
//  Created by Gustavo Gonzalez on 7/23/25.
//

import Foundation
import UIKit

var viewModel:ViewModel? = nil
var positionCoordinator:PositionCoordinator? = nil
var anchorMap: [String: Vector3D]? = nil


/// Sets the anchor map (UWB sensor positions) from a JSON string received from Unity.
///
/// This function parses a JSON string containing anchor coordinates and updates the anchor map.
/// If a `ViewModel` and `PositionCoordinator` already exist, it updates the coordinator with the new anchors
/// and disconnects from all previously connected sensors to refresh the setup.
///
/// - Parameters:
///   - str: A C-style string (UTF-8) containing a JSON map of anchor positions.
@_cdecl("setAnchorMap")
public func setAnchorMap(_ str: UnsafePointer<CChar>?) {
    guard let str = str else {
        fatalError("String parameter is nill")
    }
    
    let swiftString = String(cString: str)
    let anchorMap_ = MapReader.readCoordinatesFromString(jsonMap: swiftString)
    
    // this
    if let viewModel_ = viewModel, let positionCoordinator_ = positionCoordinator {
        positionCoordinator_.setNewAnchors(anchorsPositions: anchorMap_)
        positionCoordinator_.disconnectFromAllSensors() //*
    }
    
    anchorMap = anchorMap_ //Refresh cada nivel
    // TODO: refresh anchor map each time
}

/// Initializes the UWB plugin and starts processing using the previously defined anchor map.
///
/// This function must be called after setting the anchor map via `setAnchorMap`.
/// It initializes the `ViewModel` and `PositionCoordinator` responsible for managing sensor data and position estimation.
@_cdecl("start")
public func start() {
    print("[UWBPlugin] Start function called")
    guard anchorMap != nil else{
        fatalError("anchorMap is nill, make sure to assign a value via setAnchorMap function before.")
    }
    viewModel = ViewModel(anchorMap: anchorMap!)
    positionCoordinator = viewModel?.getPositionCoordinator()
}

/// Stops the UWB plugin, clearing all active references and data.
///
/// This function releases memory for the `ViewModel`, `PositionCoordinator`, and anchor map.
@_cdecl("stop")
public func stop(){
    print("[UWBPlugin] Stop method called.")
    
    viewModel = nil
    positionCoordinator = nil
    anchorMap = nil
}

/// Returns the most recent filtered coordinates of the user’s position as a JSON string.
///
/// - Returns: A C-style UTF-8 string representing the latest position in JSON format, e.g. `{"x": 1.2, "y": 3.4}`.
///   If no position is available, returns `{"x": null, "y": null}`.
///   The string must be manually freed using `freeCString()` after use.
@_cdecl("getCoords")
public func getCoords() -> UnsafeMutablePointer<CChar> {
    print("[UWBPlugin] getCoords function called")
    var coords: [String: Any]  // Use 'Any' so we can put Double or nil
    
    if let position = positionCoordinator?.getFilteredPosition() {
        coords = [
            "x": position.x,
            "y": position.y
        ]
    } else {
        coords = [
            "x": NSNull(),  // JSON-compatible representation of null
            "y": NSNull()
        ]
    }
    
    if let jsonData = try? JSONSerialization.data(withJSONObject: coords, options: []),
       let jsonString = String(data: jsonData, encoding: .utf8) {
        
        // Return a C string (null-terminated UTF8)
        let cString = strdup(jsonString)
        return UnsafeMutablePointer(cString!)
    } else {
        // Return an empty JSON object on error
        return strdup("{}")
    }
}
//*
/// Frees a C-style UTF-8 string previously allocated by `getCoords()`.
///
/// - Parameters:
///   - ptr: The pointer to the C string to be freed.
@_cdecl("freeCString")
public func freeCString(_ ptr: UnsafeMutablePointer<CChar>?) {
    print("[UWBPlugin] Memory freed")
    if let ptr = ptr {
        free(ptr)
    }
}


/// Forces a UI refresh by simulating app background and foreground transitions.
///
/// This is a workaround for Unity-related UI desynchronization issues on iOS.
/// It posts system notifications mimicking background and foreground events to refresh the UI layer.
@_cdecl("triggerUIRefresh")
public func triggerUIRefresh() {
    print("[UWBPlugin] Triggering UI refresh workaround")
    
    DispatchQueue.main.async {
        // Simulate app going to background
        NotificationCenter.default.post(
            name: UIApplication.didEnterBackgroundNotification,
            object: UIApplication.shared
        )
        
        // Immediately simulate coming back to foreground (no delay)
        NotificationCenter.default.post(
            name: UIApplication.willEnterForegroundNotification,
            object: UIApplication.shared
        )
        NotificationCenter.default.post(
            name: UIApplication.didBecomeActiveNotification,
            object: UIApplication.shared
        )
        
        print("[UWBPlugin] UI refresh workaround completed")
    }
}
