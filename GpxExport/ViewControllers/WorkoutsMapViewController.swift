//
//  WorkoutsMapViewController.swift
//  GpxExport
//
//  Created by Patrick Steiner on 21.08.19.
//  Copyright © 2019 Mario Martelli. All rights reserved.
//

import UIKit
import MapKit

final class WorkoutsMapViewController: UIViewController {
    @IBOutlet weak var mapView: MKMapView!

    private lazy var workoutStore: WorkoutDataStore = {
        return WorkoutDataStore()
    }()

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        loadData()
    }

    // MARK: Data source

    private func loadData() {
        workoutStore.loadWorkouts { result in
            switch result {
            case .success(let workouts):
                let dispatchGroup = DispatchGroup()
                var routes = [Route]()

                for workout in workouts {
                    dispatchGroup.enter()

                    self.workoutStore.route(for: workout) { result in
                        switch result {
                        case .success(let locations):
                            routes.append(Route(activityType: workout.workoutActivityType, locations: locations))

                            dispatchGroup.leave()
                        case .failure(let error):
                            print(error)

                            dispatchGroup.leave()
                        }
                    }
                }

                dispatchGroup.notify(queue: .main) {
                    self.setRoutes(routes: routes)
                }
            case .failure(let error):
                print(error)
            }
        }
    }

    // MARK: UI

    private func setupUI() {
        mapView.delegate = self
    }

    private func setRoutes(routes: [Route]) {
        for route in routes where route.polyline.boundingMapRect.size.height > 0 {
            mapView.addOverlay(route.polyline)
        }
    }
}

// MARK: - MKMapViewDelegate

extension WorkoutsMapViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let polylineRender = MKPolylineRenderer(overlay: overlay)

        if let workoutPolyline = overlay as? WorkoutPolyline {
            polylineRender.strokeColor = workoutPolyline.color
            polylineRender.lineWidth = 3
        }

        return polylineRender
    }
}
