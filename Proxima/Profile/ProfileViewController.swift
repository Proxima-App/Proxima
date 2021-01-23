//
//  ProfileViewController.swift
//  Proxima
//

import UIKit
import Parse
import SkeletonView

/// View controller for Profile
class ProfileViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, SkeletonCollectionViewDataSource  {

    @IBOutlet weak var profileImage: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var starsLabel: UILabel!
    
    @IBOutlet weak var addedLocationsCollectionView: UICollectionView!
    @IBOutlet weak var visitedLocationsCollectionView: UICollectionView!
    
    var currentUser: PFUser!
    var createdLocations: [PFObject] = []
    var visitedLocations: [PFObject] = []
    var achievements: [String] = []

    /**
     Called when view loads
     */
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.isSkeletonable = true
        view.showSkeleton()
        view.startSkeletonAnimation()
        
        self.addedLocationsCollectionView.isSkeletonable = true
        self.addedLocationsCollectionView.showAnimatedSkeleton()
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(ProfileViewController.handleModalDismissed),
                                               name: NSNotification.Name(rawValue: "modalDismissed"),
                                               object: nil)
        
        addedLocationsCollectionView.delegate = self
        addedLocationsCollectionView.dataSource = self
        
        visitedLocationsCollectionView.delegate = self
        visitedLocationsCollectionView.dataSource = self

        // Configure collection view layout
        let layout = addedLocationsCollectionView.collectionViewLayout as! UICollectionViewFlowLayout
        
        // Space between rows
        layout.minimumLineSpacing = 20
    }
    
    /**
     Called when view appears
     */
    override func viewDidAppear(_ animated: Bool) {

        if(currentUser == nil && PFUser.current() == nil) {
            self.performSegue(withIdentifier: "loginSegue", sender: self)
            return
        }
        
        super.viewDidAppear(animated)
    
        populate()
    }
    
    /**
     Reloads data when modal is closed
     */
    @objc func handleModalDismissed() {
        createdLocations.removeAll()
        visitedLocations.removeAll()
        addedLocationsCollectionView.reloadData()
        visitedLocationsCollectionView.reloadData()
        populate()
    }
    
    /**
     Segues to profile editing screen
     */
    @objc func editProfile() {
        performSegue(withIdentifier: "toEditProfile", sender: self)
    }
    
    /**
     Loads user info
     */
    func populate(){
        
        // Set user
        if(self.currentUser == nil) {
            self.currentUser = PFUser.current()!
        }
        
        // If user logged in, show logout and edit profile button (only on Profile tab, not leaderboard)
        if(PFUser.current() == currentUser) {
            let infoButton = UIBarButtonItem(title: "Info", style: UIBarButtonItem.Style.plain, target: self, action: Selector("showInfo"))
            navigationItem.rightBarButtonItem = infoButton
            infoButton.image = UIImage(systemName:"info.circle")
            
            let editProfileButton = UIBarButtonItem(title: "Edit Profile", style: UIBarButtonItem.Style.plain, target: self, action: Selector("editProfile"))
            navigationItem.leftBarButtonItem = editProfileButton
            editProfileButton.image = UIImage(systemName:"gear")
        }
        
        // User name
        self.nameLabel.text = currentUser?["name"] as? String

        // User score
        let score = currentUser?["score"] as? Int ?? 0
        self.starsLabel.text = "⭐️ " + String(score)

        // User profile image
        if currentUser?["profile_image"] != nil {
            let imageFile = currentUser?["profile_image"] as! PFFileObject
            let imageUrl = URL(string: imageFile.url!)!
            self.profileImage.af.setImage(withURL: imageUrl)
        }
        
        self.createdLocations = (currentUser["created_locations"] as? [PFObject]) ?? []
        self.visitedLocations = (currentUser["visited_locations"] as? [PFObject]) ?? []
        
        // Check that all visited locations still exist, if not remove from db and local array
        for location in visitedLocations {
            location.fetchInBackground { (loc, error) in
                if loc == nil {
                    // Remove location on front-end
                    self.visitedLocations.remove(at: self.visitedLocations.firstIndex(of: location)!)
                    
                    // If profile is of current user, remove location from user's profile on backend
                    if(PFUser.current() == self.currentUser) {
                        PFUser.current()?.remove(location, forKey: "visited_locations")
                        PFUser.current()?.saveInBackground()
                    }
                }
                self.visitedLocationsCollectionView.reloadData()
            }
        }
        
        addedLocationsCollectionView.reloadData()
        visitedLocationsCollectionView.reloadData()
        view.hideSkeleton(reloadDataAfter: true, transition: .crossDissolve(0.25))
    }

    
    /**
     Tell SkeletonView reusable cell identifier
     */
    func collectionSkeletonView(_ skeletonView: UICollectionView, cellIdentifierForItemAt indexPath: IndexPath) -> ReusableCellIdentifier {
        return "LocationHorizontalCell"
    }
    
    /**
     Returns number of created locations to load from user
     */
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == addedLocationsCollectionView {
            return createdLocations.count
        }
        else {
            return visitedLocations.count
        }
    }
    
    /**
     Logic for creating Shared Location cells
     */
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    
        if collectionView == addedLocationsCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "LocationHorizontalCell", for: indexPath) as! LocationHorizontalCell
            
            let location = self.createdLocations[indexPath.row] as! PFObject
            
            // Loads each location associated with this user
            location.fetchIfNeededInBackground { (location, error) in
                if location != nil {
                    cell.nameLabel.text = location!["name"] as! String
                    // Set image
                    let imageFile = location?["image"] as? PFFileObject ?? nil
                    
                    if(imageFile != nil) {
                        let imageUrl = URL(string: (imageFile?.url!)!)
                        cell.imageView?.af.setImage(withURL: imageUrl!)
                        
                    } else {
                        cell.imageView.image = nil
                    }

                }
            }
            
            return cell
        }
        else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "LocationHorizontalCell", for: indexPath) as! LocationHorizontalCell
            
            let location = self.visitedLocations[indexPath.row] as! PFObject
            
            // Loads each location associated with this user
            location.fetchIfNeededInBackground { (location, error) in
                if location != nil {
                    
                    cell.nameLabel.text = location!["name"] as! String
                    // Set image
                    let imageFile = location?["image"] as? PFFileObject ?? nil
                    
                    if(imageFile != nil) {
                        let imageUrl = URL(string: (imageFile?.url!)!)
                        cell.imageView?.af.setImage(withURL: imageUrl!)
                        
                    } else {
                        cell.imageView.image = nil
                    }
                    
                }
            }
            
            return cell
        }
    }
    
    /**
     Returns number of rows in section, one per achievement
     */
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        return achievements.count
    }
    
    /**
     Show info page
     */
    @objc func showInfo() {
        performSegue(withIdentifier: "toInfo", sender: self)
    }

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        // Prepares profile to location segue
        // Loads location then passes it to locationViewController
        if segue.identifier == "profileToSharedLocation" {
            let cell = sender as! UICollectionViewCell
            let indexPath = addedLocationsCollectionView.indexPath(for: cell)!
            
            // Pass the selected object to the new view controller.
            let locationViewController = segue.destination as! LocationViewController
            let location = createdLocations[indexPath.row].fetchIfNeededInBackground { (location, error) in
                if location != nil {
                    locationViewController.location = location
                } else {
                    print("Error: \(error?.localizedDescription) ")
                }
                
            }
        }
        
        if segue.identifier == "profileToVisitedLocation" {
            let cell = sender as! UICollectionViewCell
            let indexPath = visitedLocationsCollectionView.indexPath(for: cell)!
            
            // Pass the selected object to the new view controller.
            let locationViewController = segue.destination as! LocationViewController
            let location = visitedLocations[indexPath.row].fetchIfNeededInBackground { (location, error) in
                if location != nil {
                    locationViewController.location = location
                } else {
                    print("Error: \(error?.localizedDescription) ")
                }
                
            }
        }
    }
    

}
