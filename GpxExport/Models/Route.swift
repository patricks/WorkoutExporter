//
//  Route.swift
//  GpxExport
//
//  Created by Patrick Steiner on 21.08.19.
//  Copyright © 2019 Mario Martelli. All rights reserved.
//

import MapKit
import HealthKit

struct Route {
    var locations: [CLLocation]
    var activityType: HKWorkoutActivityType

    var polyline: WorkoutPolyline {
        let coordinates = locations.map { $0.coordinate }

        let polyline = WorkoutPolyline(coordinates: coordinates, count: coordinates.count)
        polyline.activityType = activityType

        return polyline
    }

    init(activityType: HKWorkoutActivityType, locations: [CLLocation]) {
        self.activityType = activityType
        self.locations = locations
    }
}
