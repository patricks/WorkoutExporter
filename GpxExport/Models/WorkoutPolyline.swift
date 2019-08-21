//
//  WorkoutPolyline.swift
//  GpxExport
//
//  Created by Patrick Steiner on 22.08.19.
//  Copyright © 2019 Mario Martelli. All rights reserved.
//

import HealthKit
import MapKit

class WorkoutPolyline: MKPolyline {
    var activityType: HKWorkoutActivityType?

    var color: UIColor {
        guard let activityType = activityType else { return .workoutDefault }

        return activityType.color.withAlphaComponent(0.5)
    }
}
