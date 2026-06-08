//
//  Math.swift
//  UWBplugin
//
//  Created by Gustavo Gonzalez on 9/1/25.
//
import Accelerate


public func solveQuadratic(a: Double, b: Double, c: Double, discriminant: Double) -> [Double]? {
    guard a != 0 else { return nil } // Not a quadratic
    guard discriminant >= 0 else { return nil } // No real roots

    let sqrtDisc = sqrt(discriminant)
    let root1 = (-b + sqrtDisc) / (2 * a)
    let root2 = (-b - sqrtDisc) / (2 * a)
    return [root1, root2]
}

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
