//
//  HKWorkoutActivityType+UI.swift
//  GpxExport
//
//  Created by Patrick Steiner on 22.08.19.
//  Copyright © 2019 Mario Martelli. All rights reserved.
//

import HealthKit
import UIKit

extension HKWorkoutActivityType {
    var color: UIColor {
        switch self {
        case .cycling:
            return .workoutCycling
        case .hiking:
            return .workoutHiking
        case .running:
            return .workoutRunning
        case .swimming:
            return .workoutSwimming
        case .walking:
            return .workoutWalking
        default:
            return .workoutDefault
        }
    }

    var image: UIImage {
        switch self {
        case .cycling:
            return #imageLiteral(resourceName: "Cycle")
        case .hiking:
            return #imageLiteral(resourceName: "Hike")
        case .running:
            return #imageLiteral(resourceName: "Run")
        case .swimming:
            return #imageLiteral(resourceName: "Swim")
        case .walking:
            return #imageLiteral(resourceName: "Still")
        default:
            return #imageLiteral(resourceName: "Still")
        }
    }
}
