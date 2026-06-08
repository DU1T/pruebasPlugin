//
//  Math.swift
//  UWBplugin
//
//  Created by Gustavo Gonzalez on 9/1/25.
//
import Accelerate

/// Solves a quadratic equation of the form `ax² + bx + c = 0`.
///
/// This function returns the two real roots if they exist, or `nil` if the equation
/// is not quadratic (`a == 0`) or if there are no real solutions (`discriminant < 0`).
///
/// - Parameters:
///   - a: The coefficient of `x²`.
///   - b: The coefficient of `x`.
///   - c: The constant term.
///   - discriminant: The discriminant value, usually computed as `b² - 4ac`.
/// - Returns: An array containing the two real roots, or `nil` if no real solutions exist.
public func solveQuadratic(a: Double, b: Double, c: Double, discriminant: Double) -> [Double]? {
    guard a != 0 else { return nil } // Not a quadratic
    guard discriminant >= 0 else { return nil } // No real roots

    let sqrtDisc = sqrt(discriminant)
    let root1 = (-b + sqrtDisc) / (2 * a)
    let root2 = (-b - sqrtDisc) / (2 * a)
    return [root1, root2]
}


/// Performs matrix multiplication using Apple’s Accelerate framework.
///
/// Multiplies two matrices `A` and `B` and returns the resulting matrix `C`.
/// Internally uses `vDSP_mmulD` for efficient double-precision computation.
///
/// - Parameters:
///   - A: The first input matrix (flattened in row-major order).
///   - rowsOfA: The number of rows in matrix `A`.
///   - B: The second input matrix (flattened in row-major order).
///   - colsOfB: The number of columns in matrix `B`.
///   - sharedDim: The shared dimension between `A` and `B` (number of columns in `A`, number of rows in `B`).
/// - Returns: The resulting matrix `C`, flattened in row-major order.
///
/// - Precondition:  
///   `A.count == rowsOfA * sharedDim` and  
///   `B.count == sharedDim * colsOfB`.
public func matrixMultiplication(A: [Double], rowsOfA: Int, B: [Double], colsOfB: Int, sharedDim: Int) -> [Double] {
    precondition(A.count == rowsOfA * sharedDim)
    precondition(B.count == sharedDim * colsOfB)
    
    var C = [Double](repeating: 0, count: rowsOfA * colsOfB)
    
    A.withUnsafeBufferPointer { aPtr in
        B.withUnsafeBufferPointer { bPtr in
            C.withUnsafeMutableBufferPointer { cPtr in
                vDSP_mmulD(aPtr.baseAddress!,
                           1,
                           bPtr.baseAddress!,
                           1,
                           cPtr.baseAddress!,
                           1,
                           vDSP_Length(rowsOfA),
                           vDSP_Length(colsOfB),
                           vDSP_Length(sharedDim))
            }
        }
    }
    return C
}

/// Transposes a given matrix (swaps rows and columns).
///
/// Internally uses the `vDSP_mtransD` function from Apple’s Accelerate framework
/// for optimized double-precision matrix transposition.
///
/// - Parameters:
///   - matrix: The input matrix flattened in row-major order.
///   - rows: The number of rows in the original matrix.
///   - cols: The number of columns in the original matrix.
/// - Returns: The transposed matrix, flattened in row-major order.
func transpose(matrix: [Double], rows: Int, cols: Int) -> [Double] {
    var result = [Double](repeating: 0, count: rows * cols)
    
    matrix.withUnsafeBufferPointer { srcPtr in
        result.withUnsafeMutableBufferPointer { dstPtr in
            vDSP_mtransD(
                srcPtr.baseAddress!,
                1,
                dstPtr.baseAddress!,
                1,
                vDSP_Length(cols),
                vDSP_Length(rows)
            )
        }
    }
    
    return result
}



/// Solves a system of linear equations using the Gauss–Jordan method.
///
/// This function uses LAPACK’s `dgelss_` routine (a least-squares solver) to compute
/// the solution vector `x` in `Ax = b`. It is capable of handling overdetermined or
/// underdetermined systems by finding the least-squares solution.
///
/// - Parameters:
///   - A: Coefficient matrix `A`, flattened in column-major order.
///   - n: The number of equations (and unknowns).
///   - b: Right-hand side vector `b`.
///   - nrhs: The number of right-hand sides (default is 1).
/// - Returns: The solution vector `x`.
///
/// - Note:  
///   If the system cannot be solved or if LAPACK reports an error,  
///   the function terminates with a fatal error.
public func gaussJordan(A: [Double], n: Int, b: [Double], nrhs: Int = 1) -> [Double]{
    var _A = A
    var _b = b
    
    // LAPACK integers
    var m = __CLPK_integer(n)
    var nCols = __CLPK_integer(n)
    var nrhs_ = __CLPK_integer(nrhs)
    var lda = m
    var ldb = max(m, nCols)
    
    // Work variables
    var s = [Double](repeating: 0.0, count: Int(min(m, nCols)))
    var rcond: Double = -1.0
    var rank: __CLPK_integer = 0
    var info: __CLPK_integer = 0
    
    // Workspace query
    var lwork: __CLPK_integer = -1
    var workQuery: Double = 0.0
    
    dgelss_(&m, &nCols, &nrhs_, &_A, &lda, &_b, &ldb, &s, &rcond, &rank, &workQuery, &lwork, &info)
    
    if info != 0 {
        fatalError("Workspace query failed: \(info)")
    }
    
    lwork = __CLPK_integer(workQuery)
    var work = [Double](repeating: 0.0, count: Int(lwork))
    
    // Actual solve
    dgelss_(&m, &nCols, &nrhs_, &_A, &lda, &_b, &ldb, &s, &rcond, &rank, &work, &lwork, &info)
    
    if info != 0 {
        fatalError("System couldn't be solved: \(info)")
    }
    
    // Solution is stored in _b[0..n-1]
    return Array(_b[0..<Int(n)])
}
