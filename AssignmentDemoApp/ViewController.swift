//
//  ViewController.swift
//  AssignmentDemoApp
//
//  Created by Mohit Gupta on 14/04/24.
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet weak var collectionView: UICollectionView?
    var isLoading = false
    let refreshControl = UIRefreshControl()
    var currentPage = 1
    let totalPages = 10000
    // Array to store image URLs
    var imageUrls: [URL] = []{
        didSet{
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.collectionView?.reloadData()
                self.currentPage += 1
                self.refreshControl.endRefreshing()
                // Hide loader when pagination is complete
                self.hideLoader()
            }
        }
    }
    
    // Cache for storing images
    var imageCache: NSCache<NSString, UIImage> = NSCache()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Fetch image URLs from Unsplash API
        refreshControl.addTarget(self, action: #selector(fetchImageURLs), for: .valueChanged)
        // Add refresh control to collection view
        if #available(iOS 10.0, *) {
            collectionView?.refreshControl = refreshControl
        } else {
            collectionView?.addSubview(refreshControl)
        }
        
        
        // Set up collection view
        collectionView?.delegate = self
        collectionView?.dataSource = self
        collectionView?.register(ImageCell.self, forCellWithReuseIdentifier: "ImageCell")
        
    }
    
}

extension ViewController: UICollectionViewDataSource {
    // MARK: - UICollectionViewDataSource
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // Return the number of items (cells) in the specified section
        return imageUrls.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // Return a configured cell for the specified index path
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageCell", for: indexPath) as! ImageCell
        
        // Load image for cell asynchronously
        let imageUrl = imageUrls[indexPath.item]
        loadImage(from: imageUrl) { image in
            cell.configure(with: image)
        }
        
        return cell
    }
    
}
extension ViewController: UICollectionViewDelegate{
    // MARK: - UICollectionViewDelegate
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        // Handle actions to be performed just before the cell is displayed
        if indexPath.item == imageUrls.count - 1, currentPage < totalPages && !isLoading{
            // Show loader when pagination starts
            showLoader()
            // Perform pagination by fetching more data
            self.fetchImageURLs()
        }
    }
}
extension ViewController{
    @objc func fetchImageURLs() {
        // Make API request to Unsplash to get image URLs
        
        let initialURL = URL(string: "\(baseUrl)?client_id=\(accessKey)&order_by=ORDER&per_page=\(currentPage)")!
        print("initialURL:- \(initialURL)")
        // Perform the API request
        URLSession.shared.dataTask(with: initialURL) { data, response, error in
            // Check for errors
            if let error = error {
                print("Error fetching image URLs: \(error)")
                return
            }
            
            // Check if response is valid
            guard let data = data, let response = response as? HTTPURLResponse else {
                print("Invalid response")
                return
            }
            
            // Check for status code indicating success
            guard response.statusCode == 200 else {
                print("HTTP status code: \(response.statusCode)")
                return
            }
            
            // Parse the JSON response
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                    // Extract image URLs from JSON response
                    let urls = json.compactMap { $0["urls"] as? [String: String] }
                        .compactMap { $0["regular"] }
                        .compactMap { URL(string: $0) }
                    
                    // Populate imageUrls array with fetched URLs
                    self.imageUrls.append(contentsOf: urls)
                    
                    
                } else {
                    print("Invalid JSON format")
                }
            } catch {
                print("Error parsing JSON: \(error)")
            }
        }.resume()
    }
    
    
    
    
    
    func loadImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        // Check if image is already cached
        if let cachedImage = imageCache.object(forKey: url.absoluteString as NSString) {
            completion(cachedImage)
            return
        }
        
        // If not cached, fetch image asynchronously
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, let image = UIImage(data: data) else {
                completion(nil)
                return
            }
            
            // Cache the image
            self.imageCache.setObject(image, forKey: url.absoluteString as NSString)
            
            DispatchQueue.main.async {
                completion(image)
            }
        }.resume()
    }
}

extension ViewController{
    func showLoader() {
        // Create and show loading indicator view
        let loaderView = UIActivityIndicatorView(style: .gray)
        loaderView.startAnimating()
        loaderView.center = CGPoint(x: collectionView?.bounds.size.width ?? 0.0 / 2, y: collectionView?.contentSize.height ?? 0.0 + 50)
        
        collectionView?.addSubview(loaderView)
        isLoading = true
    }
    
    func hideLoader() {
        // Find and remove loading indicator view from collection view
        collectionView?.subviews.forEach { subview in
            if let loaderView = subview as? UIActivityIndicatorView {
                loaderView.removeFromSuperview()
                isLoading = false
            }
        }
    }
}
