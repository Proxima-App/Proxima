//
//  MapViewController.swift
//  Proxima
//
//  Created by Craig Smith on 12/6/20.
//

import UIKit
import MapKit
import Parse

let landmarkColor = UIColor(red: 61/255, green: 183/255, blue: 224/255, alpha: 1.0)
let natureColor = UIColor(red: 22/255, green: 171/255, blue: 47/255, alpha: 1.0)
let urbanColor = UIColor(red: 232/255, green: 89/255, blue: 70/255, alpha: 1.0)
let historicColor = UIColor(red: 242/255, green: 251/255, blue: 157/255, alpha: 1.0)
let photoopColor = UIColor(red: 141/255, green: 108/255, blue: 224/255, alpha: 1.0)
let unknownColor = UIColor(red: 179/255, green: 179/255, blue: 179/255, alpha: 1.0)

class ProximaPointAnnotation : MKPointAnnotation {
    var pinTintColor: UIColor?;
    var location : PFObject?;
    var emoji : String = "";
}

class MapViewController: UIViewController, MKMapViewDelegate {

    @IBOutlet weak var map: MKMapView!
    var annotationView: MKAnnotationView!
    var locations = [PFObject]()
    var selectedAnnotation: ProximaPointAnnotation?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        map.delegate = self
        
        map.mapType = .satellite
        
        // Query to get locations from database
        let query = PFQuery(className: "Locations")
        query.includeKeys(["name", "description", "author", "lat", "long", "categories"])
        query.limit = 50
        
        // Query the database
        query.findObjectsInBackground { (locations, error) in
    
                // After results are returned, iterate through them and add points
                for location in locations as! [PFObject] {
                    
                    // Make new pin
                    let pin = ProximaPointAnnotation()
                    
                    pin.location = location
                    
                    // Set coords of pin
                    pin.coordinate = CLLocationCoordinate2D(latitude: location["lat"] as! Double, longitude: location["long"] as! Double)
                    
                    pin.title = location["name"] as! String
                    
                    // Set color of pin based on category
                    
                        // Unwrap category array
                        let categories = location["categories"] as! [String]
                        
                        // Set color
                        if (categories.contains("Photo Op")) {
                            pin.pinTintColor = photoopColor
                            pin.emoji = "📸"
                        }
                        else if (categories.contains("Nature")) {
                            pin.pinTintColor = natureColor
                            pin.emoji = "🌳"
                        }
                        else if (categories.contains("Urban")) {
                            pin.pinTintColor = urbanColor
                            pin.emoji = "🏬"
                        }
                        else if (categories.contains("Historical")) {
                            pin.pinTintColor = historicColor
                            pin.emoji = "📜"
                        }
                        else if (categories.contains("Landmark")) {
                            pin.pinTintColor = landmarkColor
                            pin.emoji = "📍"
                        }
                        else {
                            pin.pinTintColor = unknownColor
                            pin.emoji = "❓"
                        }
                    
                    // Add pin to map
                    self.map.addAnnotation(pin)
                }
        }
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: "myAnnotation") as? MKMarkerAnnotationView
        
        if annotationView == nil {
            annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "myAnnotation")
            
            annotationView?.canShowCallout = true
            
            let annotationViewButton = UIButton(frame: CGRect(x:0, y:0, width:50, height:50))
            annotationViewButton.setImage(UIImage(named: "camera"), for: .normal)
            
            annotationView?.leftCalloutAccessoryView = annotationViewButton
        } else {
            annotationView?.annotation = annotation
        }

        if let annotation = annotation as? ProximaPointAnnotation {
            // Color of marker
            annotationView?.markerTintColor = annotation.pinTintColor
            
            // Color of inner icon of marker
            annotationView?.glyphTintColor = .white
            
            // Icon of marker
            annotationView?.glyphText = annotation.emoji
        }
        
        return annotationView

    }
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        self.performSegue(withIdentifier: "mapToLocationView", sender: nil)
    }

    // Sets selectedAnnotation to the currently selected pin
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
