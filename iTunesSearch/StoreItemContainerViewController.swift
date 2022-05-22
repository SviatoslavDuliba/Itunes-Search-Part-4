
import UIKit

class StoreItemContainerViewController: UIViewController, UISearchResultsUpdating {
    
    @IBOutlet var tableContainerView: UIView!
    @IBOutlet var collectionContainerView: UIView!
    
    let searchController = UISearchController()
    let storeItemController = StoreItemController()
    var items = [StoreItem]()
    let queryOptions = ["movie", "music", "software", "ebook"]
    var searchTask: Task<Void, Never>? = nil
    var tableViewImageLoadTasks: [IndexPath: Task<Void, Never>] = [:]
    var collectionViewImageLoadTasks: [IndexPath: Task<Void, Never>] = [:]
    var tableViewDataSource: UITableViewDiffableDataSource<String,StoreItem>!
    var collectionViewDataSource: UICollectionViewDiffableDataSource<String,StoreItem>!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.searchController = searchController
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.automaticallyShowsSearchResultsController = true
        searchController.searchBar.showsScopeBar = true
        searchController.searchBar.scopeButtonTitles = ["Movies", "Music", "Apps", "Books"]
    }
    
    
    func updateSearchResults(for searchController: UISearchController) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(fetchMatchingItems), object: nil)
        perform(#selector(fetchMatchingItems), with: nil, afterDelay: 0.3)
    }
    
    func configureTableViewDataSource(_ tableView: UITableView) {
        tableViewDataSource = UITableViewDiffableDataSource<String,
           StoreItem>(tableView: tableView, cellProvider: { (tableView,
           indexPath, item) -> UITableViewCell? in
            let cell = tableView.dequeueReusableCell(withIdentifier:
               "Item", for: indexPath) as! ItemTableViewCell
    
            self.tableViewImageLoadTasks[indexPath]?.cancel()
            self.tableViewImageLoadTasks[indexPath] = Task {
                cell.titleLabel.text = item.name
                cell.detailLabel.text = item.artist
                cell.itemImageView.image = UIImage(systemName: "photo")
                do {
                    let image = try await
                       self.storeItemController.fetchImage(from:
                          item.artworkURL)
    
                cell.itemImageView.image = image
                } catch let error as NSError where error.domain ==
                   NSURLErrorDomain && error.code == NSURLErrorCancelled {
                    // Ignore cancellation errors
                } catch {
                cell.itemImageView.image = UIImage(systemName:
                       "photo")
                    print("Error fetching image: \(error)")
                }
                self.tableViewImageLoadTasks[indexPath] = nil
            }
    
            return cell
        })
    }
    
    func configureCollectionViewDataSource(_ collectionView:
       UICollectionView) {
        collectionViewDataSource = UICollectionViewDiffableDataSource<String, StoreItem>(collectionView: collectionView, cellProvider: { (collectionView, indexPath, item) -> UICollectionViewCell? in
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Item",
                                                          for: indexPath) as! ItemCollectionViewCell
    
            self.collectionViewImageLoadTasks[indexPath]?.cancel()
            self.collectionViewImageLoadTasks[indexPath] = Task {
                cell.titleLabel.text = item.name
                cell.detailLabel.text = item.artist
                cell.itemImageView.image = UIImage(systemName: "photo")
                do {
                    let image = try await self.storeItemController.fetchImage(from: item.artworkURL)
    
                    cell.itemImageView.image = image
                } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
                    // Ignore cancellation errors
                } catch {
                    cell.itemImageView.image = UIImage(systemName: "photo")
                    print("Error fetching image: \(error)")
                }
                self.collectionViewImageLoadTasks[indexPath] = nil
            }
                return cell
        })
    }
    
    var itemsSnapshot: NSDiffableDataSourceSnapshot<String, StoreItem> {
        var snapshot = NSDiffableDataSourceSnapshot<String, StoreItem>()
    
        snapshot.appendSections(["Results"])
        snapshot.appendItems(items)
    
        return snapshot
    }
    
    @IBAction func switchContainerView(_ sender: UISegmentedControl) {
        tableContainerView.isHidden.toggle()
        collectionContainerView.isHidden.toggle()
    }
    
    @objc func fetchMatchingItems() {
        
        self.items = []
        let searchTerm = searchController.searchBar.text ?? ""
        let mediaType = queryOptions[searchController.searchBar.selectedScopeButtonIndex]
    
        searchTask?.cancel()
        searchTask = Task {
            if !searchTerm.isEmpty {
                    let query = [
                    "term": searchTerm,
                    "media": mediaType,
                    "lang": "en_us",
                    "limit": "20"]
                
                do {
                    // use the item controller to fetch items
                    let items = try await storeItemController.fetchItems(matching: query)
                    if searchTerm == self.searchController.searchBar.text &&
                          mediaType == queryOptions[searchController.searchBar.selectedScopeButtonIndex] {
                        self.items = items
                    }
                } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
                } catch {
                    print(error)
                }
            } else {
                await tableViewDataSource.apply(itemsSnapshot, animatingDifferences: true) 
            }
            searchTask = nil
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue,
       sender: Any?) {
        if let tableViewController = segue.destination as?
           StoreItemListTableViewController {
            configureTableViewDataSource(tableViewController.tableView)
        }
    }
}
