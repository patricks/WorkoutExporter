//
//  WorkoutsViewController.swift
//  GpxExport
//
//  Created by Patrick Steiner on 21.08.19.
//  Copyright © 2019 Mario Martelli. All rights reserved.
//

import UIKit

final class WorkoutsViewController: UIViewController {
    private struct StoryboardIdentifier {
        static let list = "WorkoutsTableViewController"
        static let map = "WorkoutsMapViewController"
    }

    private struct SegmentIndex {
        static let list = 0
        static let map = 1
    }

    @IBOutlet weak var shareBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var segmentedControl: UISegmentedControl!

    private weak var currentViewController: UIViewController!
    private lazy var workoutsTableViewController: WorkoutsTableViewController = {
        // swiftlint:disable:next force_cast
        let viewController = storyboard?.instantiateViewController(withIdentifier: StoryboardIdentifier.list) as! WorkoutsTableViewController
        viewController.view.translatesAutoresizingMaskIntoConstraints = false
        viewController.delegate = self

        return viewController
    }()

    private lazy var workoutsMapViewController: WorkoutsMapViewController = {
        // swiftlint:disable:next force_cast
        let viewController = storyboard?.instantiateViewController(withIdentifier: StoryboardIdentifier.map) as! WorkoutsMapViewController
        viewController.view.translatesAutoresizingMaskIntoConstraints = false

        return viewController
    }()

    private lazy var sharingToolbarItem: UIBarButtonItem = {
        var barButtonItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(didPressShareBarButtonItem(_:)))
        barButtonItem.isEnabled = false

        return barButtonItem
    }()

    // MARK: Lifecycle

    override func viewDidLoad() {
        setupContainerView()

        super.viewDidLoad()

        authorizeHealthKit()
    }

    // MARK: Data source

    private func authorizeHealthKit() {
        HealthKitSetupAssistant.authorizeHealthKit { (authorized, error) in
            guard authorized else {
                let baseMessage = "HealthKit Authorization Failed"

                if let error = error {
                    print("\(baseMessage). Reason: \(error.localizedDescription)")
                } else {
                    print(baseMessage)
                }

                return
            }

            print("HealthKit Successfully Authorized.")
        }
    }

    private func exportSelected(workouts: [Workout]) {
        let alert = UIAlertController(title: NSLocalizedString("actionSheet.formatSelection.title", comment: "Format Selection Title"),
                                      message: NSLocalizedString("actionSheet.formatSelection.content", comment: "Format Selection Content"),
                                      preferredStyle: .actionSheet)

        let gpxExportAction = UIAlertAction(title: "GPX", style: .default) { _ in
            self.writeWorkoutsToFile(format: .gpx, workouts: workouts)
        }

        let fitExportAction = UIAlertAction(title: "Fit", style: .default) { _ in
            self.writeWorkoutsToFile(format: .fit, workouts: workouts)
        }

        alert.addAction(gpxExportAction)
        alert.addAction(fitExportAction)

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        present(alert, animated: true)
    }

    private func writeWorkoutsToFile(format: ExportFileType, workouts: [Workout]) {
        var targetURLs = [URL]()

        let fileExportGroup = DispatchGroup()

        for workout in workouts {
            fileExportGroup.enter()
            workout.writeFile(format) { targetURL in
                if let targetURL = targetURL {
                    targetURLs.append(targetURL)
                }

                fileExportGroup.leave()
            }
        }

        fileExportGroup.notify(queue: .main) {
            if targetURLs.count > 0 {
                let activityViewController = UIActivityViewController(activityItems: targetURLs, applicationActivities: nil)

                if let popoverPresentationController = activityViewController.popoverPresentationController {
                    popoverPresentationController.barButtonItem = nil
                }

                self.present(activityViewController, animated: true)
            }
        }
    }

    // MARK: UI

    private func setupUI() {
        setShareBarButton()
    }

    private func setShareBarButton() {
        if currentViewController is WorkoutsTableViewController {
            shareBarButtonItem.isEnabled = true
        } else {
            shareBarButtonItem.isEnabled = false
        }
    }

    private func setShareToolbarButton() {
        sharingToolbarItem.isEnabled = false

        setToolbarItems([sharingToolbarItem], animated: true)
    }

    private func setupContainerView() {
        currentViewController = workoutsTableViewController
        addChild(currentViewController)
        addSubview(subView: currentViewController.view, toView: containerView)
    }

    private func addSubview(subView: UIView, toView parentView: UIView) {
        parentView.addSubview(subView)

        var viewBindingsDict = [String: AnyObject]()
        viewBindingsDict["subView"] = subView
        parentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[subView]|",
                                                                 options: [],
                                                                 metrics: nil,
                                                                 views: viewBindingsDict))
        parentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[subView]|",
                                                                 options: [],
                                                                 metrics: nil,
                                                                 views: viewBindingsDict))
    }

    private func cycleFromViewController(oldViewController: UIViewController, toViewController newViewController: UIViewController) {
        oldViewController.willMove(toParent: nil)
        addChild(newViewController)
        addSubview(subView: newViewController.view, toView: containerView)

        newViewController.view.layoutIfNeeded()

        UIView.animate(withDuration: 0.5, animations: {
            // only need to call layoutIfNeeded here
            newViewController.view.layoutIfNeeded()
        }, completion: { _ in
            oldViewController.view.removeFromSuperview()
            oldViewController.removeFromParent()
            newViewController.didMove(toParent: self)
        })
    }

    // MARK: Action

    @IBAction func didChangeSegmentedControl(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == SegmentIndex.list {
            let newViewController = workoutsTableViewController
            cycleFromViewController(oldViewController: currentViewController, toViewController: newViewController)
            currentViewController = newViewController
        } else if sender.selectedSegmentIndex == SegmentIndex.map {
            let newViewController = workoutsMapViewController
            cycleFromViewController(oldViewController: currentViewController, toViewController: newViewController)
            currentViewController = newViewController
        }

        setShareBarButton()
    }

    @IBAction func didPressShareButton(_ sender: UIBarButtonItem) {
        if let workoutsTableViewController = currentViewController as? WorkoutsTableViewController {
            workoutsTableViewController.setEditTable()

            segmentedControl.isEnabled.toggle()
            setShareToolbarButton()
        }
    }

    @objc func didPressShareBarButtonItem(_ sender: UIBarButtonItem) {
        guard let workoutsTableViewController = currentViewController as? WorkoutsTableViewController else { return }

        workoutsTableViewController.loadSelectedWorkouts { workouts in
            self.exportSelected(workouts: workouts)
        }
    }
}

// MARK: - WorkoutsTableViewControllerDelegate

extension WorkoutsViewController: WorkoutsTableViewControllerDelegate {
    func didSelectWorkouts(count: Int?) {
        if let count = count, count > 0 {
            sharingToolbarItem.isEnabled = true
        } else {
            sharingToolbarItem.isEnabled = false
        }
    }
}
