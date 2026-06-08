//
//  UWBManagerDelegate.swift
//  UWBplugin
//
//  Created by Gustavo Gonzalez on 7/20/25.
//

protocol UWBManagerDelegate{    
    // connection functions
    func didConnect(deviceId: String)
    func didDisconnect(deviceId: String)
    
    // triggered on event functions
    func onDeviceDiscovered(deviceId: String, rssi: Double)
    func didUpdatePosition(deviceId: String, distance: Double)
    
}
