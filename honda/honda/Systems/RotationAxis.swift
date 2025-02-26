//
//  to.swift
//  PfizerOutdoCancer
//
//  Created by Dale Carman on 1/4/25.
//


/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
An enum to mark which axis to rotate.
*/
public enum RotationAxis: String, CaseIterable, Identifiable, Codable {
    public var id: String {
        return self.rawValue
    }
    
    public var axis: SIMD3<Float> {
        switch self {
        case .xAxis:
            return SIMD3<Float>(1.0, 0.0, 0.0)
        case .yAxis:
            return SIMD3<Float>(0.0, 1.0, 0.0)
        case .zAxis:
            return SIMD3<Float>(0.0, 0.0, 1.0)
        }
    }

    case xAxis = "X"
    case yAxis = "Y"
    case zAxis = "Z"
}

