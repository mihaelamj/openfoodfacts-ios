//
//  SearchTableViewController.swift
//  OpenFoodFacts
//
//  Created by Andrés Pizá Bückmann on 10/04/2017.
//  Copyright © 2017 Andrés Pizá Bückmann. All rights reserved.
//

import UIKit
import CoreGraphics

// MARK: - UIViewController

class SearchTableViewController: UIViewController {
    
    @IBOutlet fileprivate weak var tableView: UITableView!
    fileprivate var searchController: UISearchController!
    fileprivate var emptyTableView: UIView!
    fileprivate var lastQuery: String?
    fileprivate var productsResponse: ProductsResponse?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        emptyTableView = Bundle.main.loadNibNamed("EmptyProductsView", owner: self, options: nil)!.first as! UIView
        
        configureTableView()
        configureSearchController()
        configureNavigationBar()
    }
    
    fileprivate func configureTableView() {
        tableView.register(UINib(nibName: String(describing: ProductTableViewCell.self), bundle: nil), forCellReuseIdentifier: String(describing: ProductTableViewCell.self))
        
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 100
    }
    
    fileprivate func configureSearchController() {
        searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.dimsBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search for a product by name or barcode"
        searchController.searchBar.delegate = self
        searchController.hidesNavigationBarDuringPresentation = false
        definesPresentationContext = true
        tableView.tableHeaderView = searchController.searchBar
    }
    
    fileprivate func configureNavigationBar() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(named: "barcode"), style: .plain, target: self, action: #selector(scanBarcode))
    }
}

// MARK: - UITableViewDataSource

extension SearchTableViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if let response = productsResponse, let products = response.products, !products.isEmpty {
            tableView.backgroundView = nil
            tableView.separatorStyle = .singleLine
            tableView.isScrollEnabled = true
            
            return 1
        } else {
            tableView.backgroundView = emptyTableView
            tableView.separatorStyle = .none
            tableView.isScrollEnabled = false
            
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let response = productsResponse, let products = response.products {
            return products.count
        }
        
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: ProductTableViewCell.self), for: indexPath) as! ProductTableViewCell
        
        if let response = productsResponse, let products = response.products {
            cell.configure(withProduct: products[indexPath.row])
            
            if products.count == indexPath.row + 1, let pageString = response.page, let page = Int(pageString), let count = response.count, products.count < count {
                getProducts(fromService: ProductService(), page: page + 1)
            }
        }
        
        return cell
    }
}

// MARK: - UITableViewDelegate

extension SearchTableViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let products = productsResponse?.products {
            showProductDetails(product: products[indexPath.row])
        }
    }
}

// MARK: - UISearchResultsUpdating

extension SearchTableViewController: UISearchResultsUpdating {
    
    func updateSearchResults(for searchController: UISearchController) {
        if let query = searchController.searchBar.text, !query.isEmpty {
            getProducts(fromService: ProductService() ,page: 1, withQuery: query)
        }
    }
}

// MARK: - UISearchBarDelegate

extension SearchTableViewController: UISearchBarDelegate {
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchBar.setShowsCancelButton(true, animated: true)
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchBar.setShowsCancelButton(false, animated: true)
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        productsResponse = nil
        tableView.reloadData()
    }
}

// MARK: - Data source

extension SearchTableViewController {
    
    func getProducts(fromService service: ProductService, page: Int, withQuery query: String? = nil) {
        // Either we have a query from the user's input or we need need to fetch the next page for the same query
        if let query = query ?? productsResponse?.query {
            
            if query.isNumber() { // TODO Should validate so only the API is called when the input is a valid barcode
                service.getProduct(byBarcode: query) { product in
                    self.showProductDetails(product: product)
                }
            } else {
                service.getProducts(byName: query, page: page) { response in
                    // TODO If this query returns only a product, should it go directly to detail view instead of the tableview?
                    if self.productsResponse == nil || self.productsResponse?.query != query { // Got new response
                        self.productsResponse = response
                        self.productsResponse!.query = query
                    } else if self.productsResponse?.query == query, let newProducts = response.products { // Append new projects to existing response
                        self.productsResponse!.products!.append(contentsOf: newProducts)
                    }
                    
                    self.tableView.reloadData()
                }
            }
        }
    }
}

// MARK: - Private functions
private extension SearchTableViewController {
    func showProductDetails(product: Product) {
        navigationController?.pushViewController(productDetails(product: product), animated: true)
    }
    
    func productDetails(product: Product) -> ProductDetailViewController {
        let storyboard = UIStoryboard(name: String(describing: ProductDetailViewController.self), bundle: nil)
        let productDetailVC = storyboard.instantiateInitialViewController() as! ProductDetailViewController
        productDetailVC.product = product
        return productDetailVC
    }
}

// MARK: - Scanning

extension SearchTableViewController {
    
    func scanBarcode() {
        navigationController?.pushViewController(ScannerViewController(), animated: true)
    }
}