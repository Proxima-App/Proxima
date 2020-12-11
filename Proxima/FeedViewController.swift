//
//  FeedViewController.swift
//  Proxima
//
//  Created by Avni Avdulla on 11/21/20.
//

import UIKit
import Parse
import AlamofireImage

class FeedViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {


    @IBOutlet weak var tableView: UITableView!
    
    var locations = [PFObject]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let query = PFQuery(className: "Locations")
        query.includeKeys(["name", "description", "author", "image"])
        query.limit = 50
        
        query.findObjectsInBackground { (locations, error) in
            if locations != nil {
                self.locations = locations!
                self.tableView.reloadData()
            }
        }
        
        tableView.dataSource = self
        tableView.delegate = self
        
        self.tableView.reloadData()
        
        let timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(refresh), userInfo: nil, repeats: true)

        // Do any additional setup after loading the view.
    }

    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return locations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "FeedViewCell") as! FeedViewCell
                
        let post = locations[indexPath.row] //indexPath.section
        
        let location = post["name"] as! String
        cell.nameLabel.text = location
        
        let categories = post["categories"] as? [String] ?? []
        let categoriesString = categories.joined(separator: ", ")
        
        cell.categoriesLabel.text = categoriesString
        
        
        let imageFile = post["image"] as! PFFileObject
        let imageUrl = URL(string: imageFile.url!)!
        cell.imageView!.af.setImage(withURL: imageUrl)
        
        /*
        if post["image"] != nil {
            // Update location image
            let imageFile = post["image"] as! PFFileObject
            let imageUrl = URL(string: imageFile.url!)!
            cell.imageView!.af.setImage(withURL: imageUrl)
        }
 */
        //cell.distanceLabel.text = "0.2 miles away"
        
        //cell.nameLabel.text = "Spartan Stadium"
        
        cell.setNeedsLayout() //invalidate current layout
        cell.layoutIfNeeded() //update immediately
        
        return cell
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        
        if segue.identifier == "feedToLocation" {
            
            let cell = sender as! UITableViewCell
            let indexPath = tableView.indexPath(for: cell)!
            let location = locations[indexPath.row]
            
            // Pass the selected object to the new view controller.
            let locationViewController = segue.destination as! LocationViewController
            
            locationViewController.location = location
        }
 
    }
    
    @objc func refresh(){
        self.tableView.reloadData()
    }

}
