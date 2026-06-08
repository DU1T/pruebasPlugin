//
//  Vector2D.swift
//  UWBplugin
//
//  Created by Gustavo Gonzalez on 7/21/25.
//

struct Vector2D: Codable {
    let x: Double
    let y: Double
    
    func toSIMD() -> SIMD2<Double> {
        return SIMD2(x, y)
    }
}
