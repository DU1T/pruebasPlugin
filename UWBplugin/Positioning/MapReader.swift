//
//  MapReader.swift
//  UWBplugin
//
//  Created by Gustavo Gonzalez on 7/21/25.
//

import Foundation

/// A utility class responsible for loading and decoding anchor map data.
/// The map is represented as a dictionary where each key corresponds to an anchor ID
/// and each value is a `Vector3D` object containing its 3D coordinates.
class MapReader {

    /// Reads and decodes a JSON file containing anchor coordinates from the framework bundle.
    ///
    /// The JSON file must represent a dictionary in the form:
    /// ```json
    /// {
    ///   "anchor_identifier_1": { "x": 1.0, "y": 2.0, "z": 3.0 },
    ///   "anchor__identifier_2": { "x": 4.0, "y": 5.0, "z": 6.0 }
    /// }
    /// ```
    ///
    /// - Parameter fileName: The name of the JSON file to read, including its extension (e.g. `"anchorMap.json"`).
    /// - Returns: A dictionary mapping each anchor’s identifier to its 3D coordinates.
    ///
    /// - Note: The file must be located within the framework’s bundle.
    ///         If the file cannot be found or decoded, the method will terminate with a fatal error.
    static func readCoordinates(from fileName: String) -> [String: Vector3D] {
        let fileComponents = fileName.split(separator: ".")
        guard fileComponents.count == 2 else {
            fatalError("Invalid filename format. Expected 'name.extension'")
        }
        
        let name = String(fileComponents[0])
        let ext = String(fileComponents[1])
        
        let bundle = Bundle(for: MapReader.self)
        guard let fileURL = bundle.url(forResource: name, withExtension: ext) else {
            fatalError("File not found in framework bundle")
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
    
    /// Decodes a JSON string representing an anchor map into a dictionary of coordinates.
    ///
    /// This method allows dynamic loading of anchor maps received as raw JSON strings,
    /// for example from an API response or a Unity bridge call.
    ///
    /// - Parameter jsonMap: A JSON string containing the anchor coordinate data.
    /// - Returns: A dictionary mapping each anchor’s identifier to its `Vector3D` coordinates.
    ///
    /// - Note: If the JSON string is invalid or decoding fails, the method will terminate with a fatal error.
    static func readCoordinatesFromString(jsonMap: String) -> [String: Vector3D] {
        do {
            let data = Data(jsonMap.utf8)
            let decoder = JSONDecoder()
            let result = try decoder.decode([String: Vector3D].self, from: data)
            return result
        } catch {
            fatalError("Failed to read or decode JSON: \(error)")
        }
    }
    
}
