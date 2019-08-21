//
//  WorkoutDataStore.swift
//  GpxExport
//
//  Created by Mario Martelli on 30.11.17.
//  Copyright © 2017 Mario Martelli. All rights reserved.
//

import HealthKit
import CoreLocation

typealias HeartRateCompletionHandler = (Result<[HKQuantitySample], Error>) -> Void
typealias LocationCompletionHandler = (Result<[CLLocation], Error>) -> Void
typealias WorkoutCompletionHandler = (Result<[HKWorkout], Error>) -> Void

class WorkoutDataStore {
    private var healthStore: HKHealthStore

    init() {
        healthStore = HKHealthStore()
    }

    func heartRate(for workout: HKWorkout, completion: @escaping HeartRateCompletionHandler) {
        var allSamples = [HKQuantitySample]()

        let hrType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate)!
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate, options: HKQueryOptions.strictStartDate)

        let heartRateQuery = HKSampleQuery(sampleType: hrType,
                                           predicate: predicate,
                                           limit: HKObjectQueryNoLimit,
                                           sortDescriptors: [sortDescriptor]) { (_, samples, error) in
                                            guard let heartRateSamples: [HKQuantitySample] = samples as? [HKQuantitySample], error == nil else {
                                                completion(.failure(error!))
                                                return
                                            }

                                            if heartRateSamples.count == 0 {
                                                completion(.success([HKQuantitySample]()))
                                                return
                                            }

                                            for heartRateSample in heartRateSamples {
                                                allSamples.append(heartRateSample)
                                            }

                                            completion(.success(allSamples))
        }

        healthStore.execute(heartRateQuery)
    }

    func route(for workout: HKWorkout, completion: @escaping LocationCompletionHandler) {
        let routeType = HKSeriesType.workoutRoute()
        let predicate = HKQuery.predicateForObjects(from: workout)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let query = HKSampleQuery(sampleType: routeType,
                                  predicate: predicate,
                                  limit: HKObjectQueryNoLimit,
                                  sortDescriptors: [sortDescriptor]) { (_, samples, error) in
                                    if let error = error {
                                        print(error)
                                        completion(.failure(error))
                                        return
                                    }

                                    var routeLocations = [CLLocation]()
                                    guard let routeSamples: [HKWorkoutRoute] = samples as? [HKWorkoutRoute] else {
                                        completion(.failure(WorkoutDataStoreError.noRouteSamples))
                                        return
                                    }

                                    if routeSamples.count == 0 {
                                        completion(.success([CLLocation]()))
                                        return
                                    }

                                    var sampleCounter = 0

                                    for routeSample: HKWorkoutRoute in routeSamples {
                                        let locationQuery = HKWorkoutRouteQuery(route: routeSample) { _, locationResults, done, error in
                                            if let error = error {
                                                print("Error occured while querying for locations: \(error.localizedDescription)")
                                                completion(.failure(error))

                                                return
                                            }

                                            guard let locations = locationResults else {
                                                completion(.failure(WorkoutDataStoreError.queryError))
                                                return
                                            }

                                            if done {
                                                sampleCounter += 1
                                                if sampleCounter != routeSamples.count {
                                                    routeLocations.append(contentsOf: locations)
                                                } else {
                                                    routeLocations.append(contentsOf: locations)
                                                    let sortedLocations = routeLocations.sorted(by: {$0.timestamp < $1.timestamp})

                                                    completion(.success(sortedLocations))
                                                }
                                            } else {
                                                routeLocations.append(contentsOf: locations)
                                            }
                                        }

                                        self.healthStore.execute(locationQuery)
                                    }
        }

        healthStore.execute(query)
    }

    func loadWorkouts(completion: @escaping WorkoutCompletionHandler) {
        let predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
            HKQuery.predicateForWorkouts(with: .walking),
            HKQuery.predicateForWorkouts(with: .running),
            HKQuery.predicateForWorkouts(with: .hiking),
            HKQuery.predicateForWorkouts(with: .cycling),
            HKQuery.predicateForWorkouts(with: .swimming)
            ])

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let query = HKSampleQuery(
            sampleType: HKObjectType.workoutType(),
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]) { (_, samples, error) in
                DispatchQueue.main.async {
                    guard let samples = samples as? [HKWorkout], error == nil else {
                        completion(.failure(error!))
                        return
                    }

                    completion(.success(samples))
                }
        }

        healthStore.execute(query)
    }
}
