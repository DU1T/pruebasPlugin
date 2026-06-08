//
//  AccelerometerManager.swift
//  UWBplugin
//
//  Created by Gustavo Gonzalez on 7/20/25.
//
import CoreMotion


class AccelerometerManager{
    var delegate: AccelerometerDelegate? = nil
    var motionManager: CMMotionManager
    var refreshRate: Float
    var accelerometerQueue: OperationQueue
    
    init(refreshRate: Float, delegate: AccelerometerDelegate, accelerometerQueue: OperationQueue){
        self.accelerometerQueue = accelerometerQueue
        self.delegate = delegate
        self.refreshRate = refreshRate
        self.motionManager = CMMotionManager()
    }
}

extension AccelerometerManager{
    func startListening(){
        motionManager.startAccelerometerUpdates(to: self.accelerometerQueue) { (data, error) in
            
            guard let data = data, error == nil else {
                print("Accelerometer error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            let x = data.acceleration.x
            let y = data.acceleration.y
            
            let vector = Vector2D(x: x, y: y)
            self.delegate?.onUpdate(vector: vector)
        }
    }
    
    func stopListening(){
        self.motionManager.stopDeviceMotionUpdates()
    }
}
