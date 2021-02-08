//
//  MapViewController.swift
//  Proxima
//

import UIKit
import MapKit
import Parse

/// Pin to be displayed on interactive map
class ProximaPointAnnotation : MKPointAnnotation {
    var pinTintColor: UIColor?;
    var location : PFObject?;
    var emoji : String = "";
}

/// View controller for interactive map
class MapViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {
    
    func modalDismissed() {
        populateMap()
    }
    
    
    @IBOutlet weak var map: MKMapView!
    @IBOutlet weak var warningBox: UIView!
    var locationManager: CLLocationManager?
    
    /// Annotation view of map for ProximaPointAnnotation
    var annotationView: MKAnnotationView!
    
    /// Currently selected ProximaPointAnnotation, used for passing to segue
    var selectedAnnotation: ProximaPointAnnotation?
    
    /// Rectangle that defines geographical region to load locations for
    var loadRectangle = MKMapRect(x: 0, y: 0, width: 0, height: 0)
    
    /// If map has completed loading for the first time
    var mapDidLoad = false;
    
    /**
     Called when view loads
     */
    override func viewDidLoad() {
        super.viewDidLoad()
        map.delegate = self
        
        // Observer for modal dismissal
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(MapViewController.handleModalDismissed),
                                               name: NSNotification.Name(rawValue: "modalDismissed"),
                                               object: nil)
        
        // Location manager setup
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.requestWhenInUseAuthorization()
        locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        locationManager?.distanceFilter = kCLDistanceFilterNone
        locationManager?.startUpdatingLocation()
    
        // Adds user tracking mode toggle button to nav bar
        let buttonItem = MKUserTrackingBarButtonItem(mapView: map)
        self.navigationItem.leftBarButtonItem = buttonItem
        
        // Set default user tracking mode
        map.setUserTrackingMode(MKUserTrackingMode.follow, animated: false)
        

        
    }
    
    /**
     Called when view appears
     */
    override func viewDidAppear(_ animated: Bool) {
        populateMap()
    }
    
    func locationManager(_ manager: CLLocationManager,
                         didChangeAuthorization status: CLAuthorizationStatus) {   switch status {
          case .restricted, .denied:
            let error = UIAlertController(title: "No Location Access", message: "Proxima works better with location access by showing locations near you and rewarding points for visiting. Please go into your Settings and enable location services for Proxima.", preferredStyle: .alert)
            let okButton = UIAlertAction(title: "OK", style: .default, handler: nil)
            error.addAction(okButton)
            self.present(error, animated: true, completion: nil)
             break
                
          case .authorizedWhenInUse:
             break
                
          case .authorizedAlways:
             break
                
          case .notDetermined:
             break
       }
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
            let error = UIAlertController(title: "Not logged in", message: "Only registered users can add new locations. Go to the Profile tab to login.", preferredStyle: .alert)
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
     Calculate new rectangle (double previous size) to load locations from
     - Parameters:
     - rect : rectangle to increase
     */
    func increaseLoadRectangle(rect :MKMapRect) {
        let x = rect.minX
        let y = rect.minY
        let width = rect.width
        let height = rect.height
        loadRectangle = MKMapRect(x: (x - (width/2)), y: (y - (height/2)), width: (width*2), height: (height*2))
    }
    
    /**
     Reset map and fetch locations again
     */
    func reset() {
        map.removeAnnotations(map.annotations)
        populateMap()
    }
    
    /**
     Populate map with locations from the locations array
     */
    func populateMap() {
        // User's location
        let ne = MKMapPoint(x: loadRectangle.maxX, y: loadRectangle.minY)
        let sw = MKMapPoint(x: loadRectangle.minX, y: loadRectangle.maxY)
        
        let ne_coord = PFGeoPoint(latitude: ne.coordinate.latitude, longitude: ne.coordinate.longitude)
        let sw_coord = PFGeoPoint(latitude: sw.coordinate.latitude, longitude: sw.coordinate.longitude)
        
        let userGeoPoint = PFGeoPoint(latitude: locationManager?.location?.coordinate.latitude as? Double ?? 0, longitude: locationManager?.location?.coordinate.longitude as? Double ?? 0)
        
        // Query for places
        let query = PFQuery(className:"Locations")
        
        // Limits query to rectangle
        query.whereKey("geopoint", withinGeoBoxFromSouthwest:sw_coord, toNortheast:ne_coord)
        
        // Query the database
        query.findObjectsInBackground { (locations, error) in
            // After results are returned, iterate through them and add points
            for location in locations ?? [PFObject]() {
                // Make new pin
                let pin = ProximaPointAnnotation()
                
                pin.location = location
                
                // Set coords of pin
                let geopoint = location["geopoint"] as! PFGeoPoint
                
                pin.coordinate = CLLocationCoordinate2D(latitude: geopoint.latitude as! Double, longitude: geopoint.longitude as! Double)
                
                pin.title = location["name"] as! String
                
                // Unwrap category array
                let category = location["category"] as! String
                
                // Set color and emoji of pin based on category
                pin.emoji = category_emojis[category] ?? "❓"
                pin.pinTintColor = UIColor(hex: category_colors[category] as? String ?? "#c2c2c2")
                
                // Add pin to map
                self.map.addAnnotation(pin)
            }
        }

    }
    
    /**
     Processes annotations to show on map
     */
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: "myAnnotation") as? MKMarkerAnnotationView
        
        if annotationView == nil {
            annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "myAnnotation")
            let rightButton = UIButton(type: .detailDisclosure)
            annotationView?.rightCalloutAccessoryView = rightButton
        } else {
            annotationView?.annotation = annotation
        }
        
        // Draw user location with default view rather than with ProximaPointAnnotation
        if (annotation.isKind(of: MKUserLocation.self)){
            return nil
        }
        
        if let annotation = annotation as? ProximaPointAnnotation {
            annotationView?.canShowCallout = true
            
            // Color of marker
            annotationView?.markerTintColor = annotation.pinTintColor
            
            // Color of inner icon of marker
            annotationView?.glyphTintColor = .white
            
            // Icon of marker
            annotationView?.glyphText = annotation.emoji
        }
        
        return annotationView
        
    }
    
    /**
     Called when annotation pin's popup is pressed
     */
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        self.performSegue(withIdentifier: "mapToLocationView", sender: nil)
    }
    
    /**
     Runs every time map is moved
     */
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        
        // If map view is of radius smaller than 600 miles
        if(Double(map.visibleMapRect.width) < (160934 * 100)) {
            warningBox.isHidden = true
            
            // If previously loaded view fully contains new view
            if(!loadRectangle.contains(map.visibleMapRect)) {
                
                // If loadRectangle was reset after going out of bounds,
                // set it back to the visible map view
                if(loadRectangle.width == 0) {
                    loadRectangle = map.visibleMapRect
                }
                
                increaseLoadRectangle(rect: map.visibleMapRect)
                populateMap()
            }
        } else {
            if(mapDidLoad) {
                warningBox.isHidden = false
                
                // Reset load rectangle when out of range, forcing map to repopulate
                // when back in range
                loadRectangle = MKMapRect(x: 0, y: 0, width: 0, height: 0)
            }
        }
        
    }
    
    /**
     Runs the first time map tiles load with non-null and valid (non-zero) location (first time GPS becomes available)
     */
    func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
        let lat = locationManager?.location?.coordinate.latitude
        if(!mapDidLoad && locationManager?.location?.coordinate.latitude != 0 && locationManager?.location?.coordinate.latitude != nil) {
            map.reloadInputViews()
            increaseLoadRectangle(rect: map.visibleMapRect)
            mapDidLoad = true
        }
    }
    
    /**
     Sets selectedAnnotation to the currently selected pin
     */
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        self.selectedAnnotation = view.annotation as? ProximaPointAnnotation
    }
    
    // MARK: - Navigation
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        if segue.identifier == "mapToLocationView" {
            let locationViewController = segue.destination as! LocationViewController
            
            // Set location of LocationViewController to that of the selected pin
            locationViewController.location = self.selectedAnnotation?.location as! PFObject
        }
    }
    
    
}

extension UIColor {
    public convenience init?(hex: String) {
        let r, g, b, a: CGFloat

        if hex.hasPrefix("#") {
            let start = hex.index(hex.startIndex, offsetBy: 1)
            let hexColor = String(hex[start...])

            if hexColor.count == 6 {
                let scanner = Scanner(string: hexColor)
                var hexNumber: UInt64 = 0

                if scanner.scanHexInt64(&hexNumber) {
                    r = CGFloat((hexNumber & 0xff0000) >> 16) / 255
                    g = CGFloat((hexNumber & 0x00ff00) >> 8) / 255
                    b = CGFloat(hexNumber & 0x0000ff) / 255
                    a = 1

                    self.init(red: r, green: g, blue: b, alpha: a)
                    return
                }
            }
        }

        return nil
    }
}
