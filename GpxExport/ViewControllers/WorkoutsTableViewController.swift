import UIKit
import HealthKit

protocol WorkoutsTableViewControllerDelegate: class {
    func didSelectWorkouts(count: Int?)
}

final class WorkoutsTableViewController: UITableViewController {
    private enum WorkoutsSegues: String {
        case detailViewSegue
        case finishedCreatingWorkout
    }

    private lazy var workoutStore: WorkoutDataStore = {
        return WorkoutDataStore()
    }()

    weak var delegate: WorkoutsTableViewControllerDelegate?

    private var workouts: [HKWorkout]?
    private var tableSections: [String]?
    private var workoutSections = [String: [HKWorkout]]()
    private let tableCellIdentifier = "WorkoutTableViewCell"

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        reloadWorkouts()
    }

    // MARK: Data source

    private func reloadWorkouts() {
        workoutStore.loadWorkouts { result in
            switch result {
            case .success(let workouts):
                let watchWorkouts = workouts.filter {
                    if let filter = $0.sourceRevision.productType?.contains("Watch") {
                        return filter
                    } else {
                        return false
                    }
                }

                self.workouts = watchWorkouts
                self.tableSections = []

                self.workoutSections = [:]
                for workout in watchWorkouts {
                    let key = workout.formattedStartDateForSection
                    if self.workoutSections[key] == nil {
                        self.workoutSections[key] = [workout]
                        self.tableSections?.append(key)
                    } else {
                        self.workoutSections[key]?.append(workout)
                    }
                }

                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            case .failure(let error):
                print(error)
            }
        }
    }

    @objc func handleRefresh(refreshControl: UIRefreshControl) {
        reloadWorkouts()
        tableView.reloadData()
        refreshControl.endRefreshing()
    }

    func loadSelectedWorkouts(completion: @escaping ([Workout]) -> Void) {
        guard let selectedWorkouts = tableView.indexPathsForSelectedRows else { return }

        var workouts = [Workout]()
        let group = DispatchGroup()

        for index in selectedWorkouts {
            if let section = tableSections?[index.section], let workout = workoutSections[section]?[index.row] {
                group.enter()
                workoutStore.heartRate(for: workout) { result in
                    switch result {
                    case .success(let heartRateSamples):
                        self.workoutStore.route(for: workout) { result in
                            switch result {
                            case .success(let locations):
                                workouts.append(Workout(workout: workout, locations: locations, heartRate: heartRateSamples))
                                group.leave()
                            case .failure(let error):
                                print(error.localizedDescription)

                                group.leave()
                            }
                        }
                    case .failure(let error):
                        print(error.localizedDescription)

                        group.leave()
                    }
                }
            }
        }

        group.notify(queue: .main) {
            completion(workouts)
        }
    }

    // MARK: UI

    private func setupUI() {
        tableView.register(UINib(nibName: "WorkoutTableViewCell", bundle: nil), forCellReuseIdentifier: tableCellIdentifier)

        refreshControl?.addTarget(self, action: #selector(handleRefresh(refreshControl:)), for: UIControl.Event.valueChanged)

        navigationController?.setToolbarHidden(true, animated: false)
    }

    func setEditTable() {
        if tableView.isEditing {
            tableView.setEditing(false, animated: true)
            navigationController?.setToolbarHidden(true, animated: true)
        } else {
            tableView.setEditing(true, animated: true)
            navigationController?.setToolbarHidden(false, animated: true)
        }
    }

    // MARK: UITableViewDataSource, UITableViewDelegate

    override func numberOfSections(in tableView: UITableView) -> Int {
        if workoutSections.isEmpty {
            let emptyLabel = UILabel(frame: CGRect(x: 0, y: 0, width: tableView.bounds.size.width, height: tableView.bounds.size.height))
            emptyLabel.text = NSLocalizedString("workouts.loading", comment: "")
            if #available(iOS 13.0, *) {
                emptyLabel.textColor = .label
            } else {
                emptyLabel.textColor = .black
            }
            emptyLabel.textAlignment = .center

            tableView.backgroundView = emptyLabel
            tableView.separatorStyle = .none
        } else {
            tableView.separatorStyle = .singleLine
            tableView.backgroundView = nil
        }

        return workoutSections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let key = tableSections?[section], let workouts = workoutSections[key] {
            return workouts.count
        } else {
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: tableCellIdentifier, for: indexPath)

        if let section = tableSections?[indexPath.section], let workout = workoutSections[section]?[indexPath.row] {
            configureWorkoutTableViewCell(cell, with: workout)
        }

        return cell
    }

    private func configureWorkoutTableViewCell(_ cell: UITableViewCell, with workout: HKWorkout) {
        guard let cell = cell as? WorkoutTableViewCell else { return }

        cell.dateLabel.text = workout.formattedStartDate
        cell.workoutTypeLabel.text = workout.formattedWorkoutType
        cell.distanceLabel.text = workout.formattedTotalDistance
        cell.durationLabel.text = workout.duration.formatted

        cell.imageLabel.image = workout.workoutActivityType.image
        cell.imageLabel.tintColor = workout.workoutActivityType.color
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView.isEditing {
            delegate?.didSelectWorkouts(count: tableView.indexPathsForSelectedRows?.count)
        } else {
            performSegue(withIdentifier: WorkoutsSegues.detailViewSegue.rawValue, sender: indexPath)
        }
    }

    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if tableView.isEditing {
            delegate?.didSelectWorkouts(count: tableView.indexPathsForSelectedRows?.count)
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return tableSections?[section]
    }

    // MARK: Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let identifier = segue.identifier else { return }

        if identifier == WorkoutsSegues.detailViewSegue.rawValue,
            let workoutDetailTableViewController = segue.destination as? WorkoutDetailTableViewController {
            guard let indexPath = sender as? IndexPath else { return }

            if let section = tableSections?[indexPath.section], let workout = workoutSections[section]?[indexPath.row] {
                workoutDetailTableViewController.hkWorkout = workout
            }
        }
    }
}
