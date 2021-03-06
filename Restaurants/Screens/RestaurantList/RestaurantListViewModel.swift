//
//  RestaurantListViewModel.swift
//  Restaurants
//
//  Created by Abbas Awan on 24.08.20.
//  Copyright © 2020 Takeaway. All rights reserved.
//

import Foundation

// MARK: - Communication protocol
protocol RestaurantListViewModelDelegate: class {
    func shouldReloadData()
}

// MARK: - Class implementation
final class RestaurantListViewModel {
    
    // MARK: - Public properties
    let sortButtonTitle = "Sort".localized
    let screenTitle = "Restaurant List".localized
    let searchPlaceholderText = "Type Restaurant name".localized
    
    let sortingOptionsViewModel: OptionPickerViewModel = {
        let sortTypes = RestaurantSortingType.allCases
        let options = sortTypes.map{ PickerOption(title: $0.title, optionKey: $0.rawValue) }
        return .init(options: options)
    }()
    
    weak var delegate: RestaurantListViewModelDelegate?
    weak var navigationDelegate: RestaurantListViewControllerNavigationDelegate?
    
    // MARK: - Private properties
    private let apiProvider: RestaurantListApiProvidable
    private let sortingProvider: RestaurantSortingProvidable
    private var sortType: RestaurantSortingType
    private var restaurants: [Restaurant] = []
    private var cellViewModels: [RestaurantListTableCellViewModel] = [] {
        didSet {
            delegate?.shouldReloadData()
        }
    }
    
    // MARK: - Lifecycle
    init(apiProvider: RestaurantListApiProvidable,
         sortingProvider: RestaurantSortingProvidable,
         defaultSortType: RestaurantSortingType) {
        self.apiProvider = apiProvider
        self.sortingProvider = sortingProvider
        sortType = defaultSortType
    }
    
    // MARK: - Public methods
    /// When view is loaded, we need to request list of restaurants.
    /// If the data loading is successful, ask to reload data, otherwise ask to show error.
    func viewDidLoad() {
        apiProvider.loadRestaurantList { [weak self] (result) in
            guard let self = self else { return }

            switch result {
            case .failure(let error):
                self.navigationDelegate?.show(error)
            case .success(let restaurants):
                self.restaurants = restaurants
                self.didSelectSortOption(self.sortType.rawValue)
            }
        }
    }
    
    func didChangeSearchBarText(_ text: String?) {
        guard let searchText = text else {
            return
        }
        
        filterRestaurantList(for: searchText)
    }
    
    func numberOfRows(in section: Int) -> Int {
        cellViewModels.count
    }
    
    func cellViewModel(at indexPath: IndexPath) -> RestaurantListTableCellViewModel? {
        guard indexPath.row < cellViewModels.count else {
            return nil
        }
        
        return cellViewModels[indexPath.row]
    }
    
    func didSelectRow(at indexPath: IndexPath) {
        // Future implementation: Show details for selected restaurant.
        // We pass the selected restaurant to navigation delegate, which should then start
        // restaurant detail flow using designated coordinator
        // navigationDelegate?.showDetails(for: restaurants[indexPath.row])
    }
    
    func didSelectSortOption(_ sortOption: String) {
        guard let sortType = RestaurantSortingType(rawValue: sortOption) else {
            return
        }
        
        self.sortType = sortType
        
        // Sort the restaurant list based on selected sort type
        restaurants.sort(by: sortingProvider.sorter(for: sortType))
        
        // Prepare table cell view models for newly sorted restaurants list
        prepareCellViewModels(from: restaurants)
    }
    
    // MARK: - Private methods
    
    /// Create list of table cell view models from the list of restaurants
    /// - Parameter restaurants: List of restaurants from which table cell view models will be created
    private func prepareCellViewModels(from restaurants: [Restaurant]) {
        var cellModels = [RestaurantListTableCellViewModel]()
        for aRestaurant in restaurants {
            cellModels.append(makeCellViewModel(with: aRestaurant))
        }
        
        if cellModels != cellViewModels {
            cellViewModels = cellModels
        }
    }
    
    /// Creates and returns cell view model from a restaurant object
    /// - Parameter restaurant: Restaurant object from which to create cell view model
    /// - Returns: Cell view model to be displayed in the list
    private func makeCellViewModel(with restaurant: Restaurant) -> RestaurantListTableCellViewModel {
        .init(title: restaurant.name,
              subtitle: cellSubtitleString(from: restaurant, for: sortType))
    }
    
    /// Returns subtitle string for the table cell. It contains 2 lines: first line contains
    /// restaurant status and second line shows selected sorting and sort value for the restaurant
    /// - Parameters:
    ///   - restaurant: Restaurant which we need to show info for
    ///   - sortType: Sort type to help pick which sort value of restaurant to use
    /// - Returns: 2 lines string which shows restaurant status and sort info
    private func cellSubtitleString(from restaurant: Restaurant,
                                    for sortType: RestaurantSortingType) -> String {
        let value: String
        
        switch sortType {
        case .bestMatch:
            value = "\(restaurant.bestMatch)"
        case .newest:
            value = "\(restaurant.newest)"
        case .ratingAverage:
            value = "\(restaurant.ratingAverage)"
        case .distance:
            value = "\(restaurant.distance)"
        case .popularity:
            value = "\(restaurant.popularity)"
        case .averageProductPrice:
            value = "\(restaurant.averageProductPrice)"
        case .deliveryCosts:
            value = "\(restaurant.deliveryCosts)"
        case .minCost:
            value = "\(restaurant.minCost)"
        }
        
        return restaurant.status.rawValue + "\n" + sortType.title + ": " + value
    }
    
    /// Filter the restaurants if their name contains the search term and
    /// update the cell view models array so that latest result can be
    /// displayed to the user
    /// - Parameter name: Name for which we need to filter the restaurant list
    private func filterRestaurantList(for name: String) {
        guard !name.isEmpty else {
            self.prepareCellViewModels(from: restaurants)
            return
        }
        
        // Filter restaurants by name, ignoring the case
        let filtered = restaurants.filter({
            $0.name.lowercased().contains(name.lowercased())
        })
        self.prepareCellViewModels(from: filtered)
    }
}
