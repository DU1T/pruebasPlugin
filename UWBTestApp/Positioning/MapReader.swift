//
//  MapReader.swift
//  UWBplugin
//
//  Created by Gustavo Gonzalez on 7/21/25.
//

import Foundation

class MapReader {
    static func readCoordinates(from fileName: String) -> [String: Vector3D] {
        let fileComponents = fileName.split(separator: ".")
        guard fileComponents.count == 2 else {
            fatalError("Invalid filename format. Expected 'name.extension'")
        }
        
        let name = String(fileComponents[0])
        let ext = String(fileComponents[1])
        
        guard let fileURL = Bundle.main.url(forResource: name, withExtension: ext) else {
            fatalError("File not found in bundle")
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let result = try decoder.decode([String: Vector3D].self, from: data)
            return result
        } catch {
            fatalError("Failed to read or decode JSON: \(error)")
        }
    }
}
