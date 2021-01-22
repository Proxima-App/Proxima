//
//  LocationTableViewController.swift
//  Proxima
//

import UIKit
import Parse
import AlamofireImage
import SkeletonView

/// View controller for the Feed
class FeedViewController: UITableViewController, SkeletonTableViewDataSource, CLLocationManagerDelegate {
    
    var locationManager: CLLocationManager?
    let tableRefreshControl = UIRefreshControl()
    
    /// Collection of Location objects to show on feed
    var locations = [PFObject]()
    
    /// User's current location
    var userGeoPoint = PFGeoPoint()
    
    /**
     Called when view loads
     */
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Observer for modal dismissal
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(MapViewController.handleModalDismissed),
                                               name: NSNotification.Name(rawValue: "modalDismissed"),
                                               object: nil)
        
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.requestWhenInUseAuthorization()
        locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        locationManager?.distanceFilter = kCLDistanceFilterNone
        locationManager?.startUpdatingLocation()
        
        tableView.dataSource = self
        
        // Important for loading in new locations with correct scroll bar size
        tableView.estimatedRowHeight = 127
        tableView.rowHeight = 127
        
        self.tableView.isSkeletonable = true
        
        tableRefreshControl.addTarget(self, action: #selector(reset), for: .valueChanged)
        tableView.refreshControl = tableRefreshControl
        
        self.tableView.hideSkeleton()
        
    }
    
    /**
     Called when view is about to appear
     */
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        reset()
        
        // Fix row offset so scroll bar starts at top
        self.tableView.contentOffset = CGPoint(x: 0, y: -63)
    }
    
    /**
     Called when Add Location/View Location modal is dismissed
     */
    @objc func handleModalDismissed() {
        reset()
    }
    
    /**
     Called when add location button is pressed
     - Parameters:
     - sender : sender passed to segue
     */
    @IBAction func onAddLocation(_ sender: Any) {
        // Disallow adding new location if user isn't logged in
        if((PFUser.current()) == nil) {
            let error = UIAlertController(title: "Not logged in", message: "Only registered users can add new locations. Go to the Profile tab to login or signup.", preferredStyle: .alert)
            let okButton = UIAlertAction(title: "OK", style: .default, handler: nil)
            error.addAction(okButton)
            self.present(error, animated: true, completion: nil)
            // Disallow adding new location if user didnt' grant location permissions
        } else if (locationManager?.location?.coordinate.latitude == nil || locationManager?.location?.coordinate.latitude == 0) {
            let error = UIAlertController(title: "No Location Permission", message: "Proxima must have permission to use your location to submit new locations.", preferredStyle: .alert)
            let okButton = UIAlertAction(title: "OK", style: .default, handler: nil)
            error.addAction(okButton)
            self.present(error, animated: true, completion: nil)
        } else {
            performSegue(withIdentifier: "toAddLocation", sender: self)
        }
    }
    
    /**
     Reset and reload the feed
     */
    @objc func reset() {
        locations = [PFObject]()
        populate(limit: 10, skip: 0)
        self.tableView.showAnimatedSkeleton()
        self.tableView.reloadData()
    }
    
    /**
     Populate map with locations from the locations array
     - Parameters:
     - limit : number of locations to be returned by query
     - skip : number of locations to skip in quqery
     */
    func populate(limit: Int, skip: Int) {
        // User's location
        userGeoPoint = PFGeoPoint(latitude: locationManager?.location?.coordinate.latitude as? Double ?? 0, longitude: locationManager?.location?.coordinate.longitude as? Double ?? 0)
        
        let query = PFQuery(className: "Locations")
        query.whereKey("geopoint", nearGeoPoint:userGeoPoint)
        
        query.limit = limit
        query.skip = skip
        
        query.findObjectsInBackground { (newLocations, error) in
            if newLocations != nil {
                self.locations.append(contentsOf: newLocations!)
            }
            self.tableView.reloadData()
            self.tableRefreshControl.endRefreshing()
            self.tableView.hideSkeleton()
            self.tableView.stopSkeletonAnimation()
            
            // Scroll to top
            self.tableView.scrollRectToVisible(CGRect(x:0, y:0, width:1, height:1), animated: false)
        }
    }
    
    // MARK: - Table view data source
    
    /**
     Returns number of sections in table view, always 1
     */
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    /**
     Returns number of rows in section, one per location
     */
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return locations.count
    }
    
    /**
     Called when feed is scrolled
     */
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        // When near end of feed, load more
        if indexPath.row + 1 == locations.count && locations.count > 0 {
            let query = PFQuery(className:"Locations")
            query.countObjectsInBackground { (count: Int32, error: Error?) in
                if let error = error {
                    print(error.localizedDescription)
                } else {
                    if(count > self.locations.count) {
                        // Load 10 more, skip for rows already created
                        self.populate(limit: 10, skip: tableView.numberOfRows(inSection: 0))
                    }
                }
            }
        }
    }
    
    /**
     Logic for creating Location Feed cells
     */
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "FeedViewCell") as! FeedViewCell
        let location = locations[indexPath.row]
        
        // Set name
        cell.nameLabel.text = location["name"] as? String
        
        // Set category
        let category = location["category"] as! String
        var emoji = ""
        
        if (category == "Art") {
            emoji = "🎨"
        }
        else if (category == "Nature") {
            emoji = "🌳"
        }
        else if (category == "Urban") {
            emoji = "🏬"
        }
        else if (category == "Rustic") {
            emoji = "🏚"
        }
        else if (category == "Historical") {
            emoji = "📜"
        }
        else if (category == "Landmark") {
            emoji = "📍"
        }
        else {
            emoji = "❓"
        }
        
        cell.categoryLabel.text = emoji + " " + category
        
        // Check that user location is valid
        if(userGeoPoint.latitude != 0) {
            // Set distance label
            let dist = userGeoPoint.distanceInMiles(to: location["geopoint"] as? PFGeoPoint)
            
            // If distance is more than 5 miles away, don't show floating point
            if(dist < 5) {
                cell.distanceLabel.text = String(format: "%.1f", dist) + " miles away"
            } else {
                cell.distanceLabel.text = String(format: "%.0f", dist) + " miles away"
            }
        } else {
            cell.distanceLabel.isHidden = true
        }
        
        // Set image
        let imageFile = location["image"] as? PFFileObject ?? nil
        
        if(imageFile != nil) {
            let imageUrl = URL(string: (imageFile?.url!)!)
            cell.locationImage?.af.setImage(withURL: imageUrl!)
            
        } else {
            cell.locationImage.image = nil
        }
        
        cell.setNeedsLayout()
        cell.layoutIfNeeded()
        
        cell.stopSkeletonAnimation()
        cell.hideSkeleton()
        
        return cell
    }
    
    /**
     Tell SkeletonView reusable cell identifier
     */
    func collectionSkeletonView(_ skeletonView: UITableView, cellIdentifierForRowAt indexPath: IndexPath) -> ReusableCellIdentifier {
        return "FeedViewCell"
    }
    
    // MARK: - Navigation
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "feedToLocation" {
            
            let cell = sender as! UITableViewCell
            let indexPath = tableView.indexPath(for: cell)!
            let location = locations[indexPath.row]
            
            // Pass the selected object to the new view controller.
            let locationViewController = segue.destination as! LocationViewController
            
            locationViewController.location = location
            
            // Deselect cell before segue
            if let path = tableView.indexPathForSelectedRow {
                tableView.deselectRow(at: path, animated: true)
            }
        }
    }
    
}
