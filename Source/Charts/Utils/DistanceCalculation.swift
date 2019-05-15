//
//  DistanceCalculation.swift
//  Charts
//
//  Created by Travis Chambers on 5/15/19.
//

import Foundation

public typealias DistanceCalculation = (_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) -> CGFloat

/// Straight line distance between two points
public let euclideanDistance: DistanceCalculation = { x1, y1, x2, y2 in
    hypot(x1 - x2, y1 - y2)
}

/// Horizontal distance between two points
public let horizontalDistance: DistanceCalculation = { x1 , _, x2, _ in
    abs(x1 - x2)
}

/// Vertical distance between two points
public let verticalDistance: DistanceCalculation = { _, y1, _, y2 in
    abs(y1 - y2)
}
