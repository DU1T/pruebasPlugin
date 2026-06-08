//
//  AccelerometerDelegate.swift
//  UWBplugin
//
//  Created by Gustavo Gonzalez on 7/20/25.
//

/// Protocol defining callbacks for accelerometer updates.
protocol AccelerometerDelegate{    
    /// Called whenever a new accelerometer reading is available.
    ///
    /// - Parameters:
    ///   - vector: The 2D vector containing the latest acceleration values after processing.
    func onUpdate(vector: Vector2D)
}
