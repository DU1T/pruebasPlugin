//
//  Kalman.swift
//  UWBplugin
//
//  Created by Gustavo Gonzalez on 7/21/25.
//
import Foundation
import simd

class KalmanFilter {
    static let shared: KalmanFilter = {
        let x = simd_double4(0, 0, 0, 0)  // initial state

        let P = simd_double4x4(rows: [
            simd_double4(0.6, 0.0, 0.0, 0.0),
            simd_double4(0.0, 0.6, 0.0, 0.0),
            simd_double4(0.0, 0.0, 1.0, 0.0),
            simd_double4(0.0, 0.0, 0.0, 1.0)
        ])

        let F = simd_double4x4(rows: [
            simd_double4(6.0, 0.0, 0.0, 0.0),
            simd_double4(0.0, 6.0, 0.0, 0.0),
            simd_double4(0.0, 0.0, 25.0, 0.0),
            simd_double4(0.0, 0.0, 0.0, 25.0)
        ])
        
        let H = simd_double4x2(rows: [
            SIMD4<Double>(1.0, 0.0, 0.0, 0.0),
            SIMD4<Double>(0.0, 1.0, 0.0, 0.0)
        ])

        let R = simd_double2x2(diagonal: simd_double2(1.0, 1.0))

        let w = simd_double4(0.5, 0.5, 0.5, 0.5)
        let Q = simd_double4x4(diagonal: w * w)

        let G = simd_double2x4(diagonal: SIMD2<Double>(0,0))
        let u = simd_double2(0.0, 0.0)

        return KalmanFilter(P: P, Q: Q, H: H, R: R, x: x, G: G, u: u, F: F)
    }()

    // MARK: - Kalman filter internals

    private(set) var x: simd_double4
    private var P: simd_double4x4
    private var F: simd_double4x4
    private var G: simd_double2x4
    private var u: simd_double2
    private var Q: simd_double4x4
    private var H: simd_double4x2
    private var R: simd_double2x2

    private init(
        P: simd_double4x4,
        Q: simd_double4x4,
        H: simd_double4x2,
        R: simd_double2x2,
        x: simd_double4,
        G: simd_double2x4,
        u: simd_double2,
        F: simd_double4x4
    ) {
        self.x = x
        self.P = P
        self.F = F
        self.G = G
        self.u = u
        self.Q = Q
        self.H = H
        self.R = R
    }

    func predict() {
        x = F * x + G * u
        P = F * P * F.transpose + Q
    }

    func update(z: simd_double2) {
        let y = z - H * x                      // Innovation
        let S = H * P * H.transpose + R        // Innovation covariance
        let K = P * H.transpose * S.inverse    // Kalman gain

        x = x + K * y                          // Updated state
        let I = matrix_identity_double4x4
        P = (I - K * H) * P                    // Updated covariance
    }

    func getX() -> simd_double4 {
        return x
    }

    func updateX(_ newX: simd_double4) {
        x = newX
    }

    func updateF(_ newF: simd_double4x4) {
        F = newF
    }

    func updateG(_ newG: simd_double2x4) {
        G = newG
    }

    func updateU(_ newU: simd_double2, kA: Double = 1.3) {
       u = simd_double2(kA * newU.x, kA * newU.y)
   }
    
    func updateF(delta_time: Double){
        self.F = simd_double4x4(
            simd_double4(1.0, 0.0, delta_time, 0.0),
            simd_double4(0.0, 1.0, 0.0, delta_time),
            simd_double4(0.0, 0.0, 1.0, 0.0),
            simd_double4(0.0, 0.0, 0.0, 1.0)
        )
    }
    
    func updateG(delta_time: Double){
        self.G = simd_double2x4(rows: [
            SIMD2<Double>(0.5*delta_time, 0),
            SIMD2<Double>(0.0, 0.5*delta_time),
            SIMD2<Double>(delta_time, 0.0),
            SIMD2<Double>(0.0, delta_time)
        ])
    }
}
