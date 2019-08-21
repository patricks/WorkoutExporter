//
//  Workout.swift
//  GpxExport
//
//  Created by Mario Martelli on 30.11.17.
//  Copyright © 2017 Mario Martelli. All rights reserved.
//

import HealthKit
import MapKit
import AntMessageProtocol

enum ExportFileType {
    case gpx
    case fit
}

struct Workout {
    private var hkWorkout: HKWorkout
    var route: Route
    var heartRate: [HKQuantitySample]
    var startDate: Date

    var activityType: String {
        return hkWorkout.formattedWorkoutType
    }

    var antSport: Sport {
        return hkWorkout.antActivity
    }

    var name: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .medium

        return "\(activityType) - \(formatter.string(from: startDate))"
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .medium

        return formatter.string(from: startDate)
    }

    var polyline: MKPolyline {
        return route.polyline
    }

    var maxHeartRate: Int {
        let bpmUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
        if let maxHeart = heartRate.map({ $0.quantity.doubleValue(for: bpmUnit) }).max() {
            return Int(maxHeart)
        } else {
            return 0
        }
    }

    var formattedMaxHeartRate: String {
        return String(format: "%d bpm", maxHeartRate)
    }

    var formattedAverageHeartRate: String {
        return String(format: "%d bpm", averageHeartRate)
    }

    private var summedHeartRate: Double {
        let bpmUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
        return heartRate.reduce(0.0, { $0 + $1.quantity.doubleValue(for: bpmUnit) })
    }

    var averageHeartRate: Int {
        return Int(summedHeartRate / Double(heartRate.count))
    }

    var duration: TimeInterval {
        return hkWorkout.duration
    }

    init(workout: HKWorkout, locations: [CLLocation], heartRate: [HKQuantitySample]) {
        self.route = Route(activityType: workout.workoutActivityType, locations: locations)
        self.heartRate = heartRate

        if let timestamp = locations.first?.timestamp {
            self.startDate = timestamp
        } else {
            self.startDate = Date()
        }
        self.hkWorkout = workout
    }

    func writeFile(_ format: ExportFileType, completionHandler: @escaping(_ url: URL?) -> Void) {
        if format == .fit {
            writeFit(completionHandler: completionHandler)
        } else {
            writeGPX(completionHandler: completionHandler)
        }
    }
}
