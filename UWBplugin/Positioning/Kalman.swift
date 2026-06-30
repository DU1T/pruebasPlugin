//
//  Kalman.swift
//  UWBplugin
//
//  Created by Gustavo Gonzalez on 7/21/25.
//
import Foundation
import simd

/// Shared singleton instance of the Kalman filter.
/// Used throughout the app to maintain a consistent and continuous estimation of user position.
/// The filter fuses UWB distance measurements and accelerometer data to smooth out noise and improve accuracy.
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

    /// Initializes a new Kalman filter with the given matrices and initial state.
    /// This method is private since the filter is accessed via the shared instance.
    ///
    /// - Parameters:
    ///   - P: Initial state covariance matrix.
    ///   - Q: Process noise covariance matrix, representing system uncertainty.
    ///   - H: Observation matrix mapping the state to measurement space.
    ///   - R: Measurement noise covariance matrix.
    ///   - x: Initial state vector (position and velocity).
    ///   - G: Control-input matrix.
    ///   - u: Control vector representing acceleration input.
    ///   - F: State transition matrix.
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

    /// Predicts the next state of the system based on the current state and motion model.
    /// This step estimates position and velocity before incorporating any new measurements.
    func predict() {
        x = F * x + G * u
        P = F * P * F.transpose + Q
    }

    /// Updates the Kalman filter using a new position measurement.
    /// Adjusts the predicted state and covariance based on the observed data to reduce error.
    ///
    /// - Parameter z: The measured position vector (e.g., from trilateration).
    func update(z: simd_double2) {
        let y = z - H * x                      // Innovation
        let S = H * P * H.transpose + R        // Innovation covariance
        let K = P * H.transpose * S.inverse    // Kalman gain

        x = x + K * y                          // Updated state
        let I = matrix_identity_double4x4
        P = (I - K * H) * P                    // Updated covariance
    }

    /// Retrieves the current estimated state vector of the system.
    ///
    /// - Returns: A 4D vector containing the estimated position (x, y) and velocity (vx, vy).
    func getX() -> simd_double4 {
        return x
    }

    /// Manually replaces the current state vector with a new one.
    ///
    /// - Parameter newX: The new state vector to set as the filter’s internal state.
    func updateX(_ newX: simd_double4) {
        x = newX
    }

    /// Updates the state transition matrix used during prediction.
    ///
    /// - Parameter newF: The new transition matrix representing how the system evolves between time steps.
    func updateF(_ newF: simd_double4x4) {
        F = newF
    }

    /// Updates the control-input matrix used to incorporate acceleration data.
    ///
    /// - Parameter newG: The new control-input matrix.
    func updateG(_ newG: simd_double2x4) {
        G = newG
    }

    //    func updateU(_ newU: simd_double2) {
    //        u = newU
    //    }
        
    /// Updates the control vector `u` based on a new acceleration measurement.
    /// A scaling factor `kA` can be applied to tune the acceleration influence on prediction.
    ///
    /// - Parameters:
    ///   - newU: The new acceleration vector.
    ///   - kA: A scaling factor applied to the acceleration input (default is 1.3)
    func updateU(_ newU: simd_double2, kA: Double = 1.3) {
        u = simd_double2(kA * newU.x, kA * newU.y)
    }
    

    /// Recomputes the state transition matrix `F` using the elapsed time between updates.
    /// This allows the filter to dynamically adjust to varying update intervals.
    ///
    /// - Parameter delta_time: Time difference (in seconds) since the last update.
    func updateF(delta_time: Double){
        self.F = simd_double4x4(
            simd_double4(1.0, 0.0, delta_time, 0.0),
            simd_double4(0.0, 1.0, 0.0, delta_time),
            simd_double4(0.0, 0.0, 1.0, 0.0),
            simd_double4(0.0, 0.0, 0.0, 1.0)
        )
    }
    
    /// Recomputes the control-input matrix `G` using the elapsed time between updates.
    /// This defines how acceleration influences position and velocity over time.
    ///
    /// - Parameter delta_time: Time difference (in seconds) since the last update.
    func updateG(delta_time: Double){
        self.G = simd_double2x4(rows: [
            SIMD2<Double>(0.5*delta_time, 0),
            SIMD2<Double>(0.0, 0.5*delta_time),
            SIMD2<Double>(delta_time, 0.0),
            SIMD2<Double>(0.0, delta_time)
        ])
    }
}
