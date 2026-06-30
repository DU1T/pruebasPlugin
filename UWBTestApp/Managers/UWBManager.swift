//
//  UWBManager.swift
//  UWBplugin
//
//  Created by Gustavo Gonzalez on 7/20/25.
//
import EstimoteUWB


class UWBManager: NSObject, ObservableObject{
    var delegate: UWBManagerDelegate
    var manager: EstimoteUWBManager? = nil
    var UWBQueue: OperationQueue
    
    init(delegate: UWBManagerDelegate, UWBQueue: OperationQueue){
        self.UWBQueue = UWBQueue
        self.delegate = delegate
        
        super.init()
        
        self.manager = EstimoteUWBManager(delegate: self, options: EstimoteUWBOptions(shouldHandleConnectivity: false, isCameraAssisted: false))
        
    }
    
    func connectTo(deviceID: String){
        UWBQueue.addOperation {
            self.manager?.connect(to: deviceID)
        }
    }
    
    func disconnectFrom(deviceId: String){
        UWBQueue.addOperation{
            self.manager?.disconnect(from: deviceId)
        }
    }
    
    func startScanning(){
        UWBQueue.addOperation {
            self.manager?.startScanning()
        }
    }
    
    func stopScanning(){
        UWBQueue.addOperation {
            self.manager?.stopScanning()
        }
    }
}

extension UWBManager: EstimoteUWBManagerDelegate{
    func didUpdatePosition(for device: EstimoteUWBDevice){
        self.UWBQueue.addOperation {            
            self.delegate.didUpdatePosition(deviceId: device.publicIdentifier, distance: Double(abs(device.distance))) // estimote sometimes returns negative distances so we pass it through the abs function
        }
    }
    
    func didDiscover(device: UWBIdentifiable, with rssi: NSNumber, from manager: EstimoteUWBManager){
        self.UWBQueue.addOperation {
            self.delegate.onDeviceDiscovered(deviceId: device.publicIdentifier, rssi: Double(truncating: rssi))
        }
    }
    
    func didConnect(to device: UWBIdentifiable){
        self.UWBQueue.addOperation {
            self.delegate.didConnect(deviceId: device.publicIdentifier)
        }
    }
    
    func didDisconnect(from device: UWBIdentifiable, error: Error?) {
        self.UWBQueue.addOperation {
            self.delegate.didDisconnect(deviceId: device.publicIdentifier)
        }
    }

    func didFailToConnect(to device: UWBIdentifiable, error: Error?) {
        self.UWBQueue.addOperation {
            self.delegate.didDisconnect(deviceId: device.publicIdentifier)
        }
    }
}
