//
//  CountryPickerViewController.swift
//  CountryPickerView
//
//  Created by Kizito Nwose on 18/09/2017.
//  Copyright © 2017 Kizito Nwose. All rights reserved.
//

import UIKit

public class CountryPickerViewController: UITableViewController {

    public var searchController: UISearchController?
    fileprivate var searchResults = [Country]()
    fileprivate var isSearchMode = false
    fileprivate var sectionsTitles = [String]()
    fileprivate var countries = [String: [Country]]()
    fileprivate var hasPreferredSection: Bool {
        return dataSource.preferredCountriesSectionTitle != nil &&
            dataSource.preferredCountries.count > 0
    }
    fileprivate var showOnlyPreferredSection: Bool {
        return dataSource.showOnlyPreferredSection
    }
    
    internal weak var countryPickerView: CountryPickerView! {
        didSet {
            dataSource = CountryPickerViewDataSourceInternal(view: countryPickerView)
        }
    }
    
    fileprivate var dataSource: CountryPickerViewDataSourceInternal!
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(iOS 10.0, *) {
            self.tableView.prefetchDataSource = self
        }
        
        prepareTableItems()
        prepareNavItem()
        prepareSearchBar()
    }
   
}

// UI Setup
extension CountryPickerViewController {
    
    public override var preferredStatusBarStyle: UIStatusBarStyle {
        return self.dataSource.preferredStatusBarStyle(in: self.countryPickerView)
    }
    
    func prepareTableItems()  {
        if !showOnlyPreferredSection {
            let countriesArray = countryPickerView.countries
            
            var groupedData = Dictionary<String, [Country]>(grouping: countriesArray) {
                let name = $0.localizedName ?? $0.name
                return String(name.capitalized[name.startIndex])
            }
            groupedData.forEach{ key, value in
                groupedData[key] = value.sorted(by: { (lhs, rhs) -> Bool in
                    return lhs.name < rhs.name
                })
            }
            
            countries = groupedData
            sectionsTitles = groupedData.keys.sorted()
        }
        
        // Add preferred section if data is available
        if hasPreferredSection, let preferredTitle = dataSource.preferredCountriesSectionTitle {
            sectionsTitles.insert(preferredTitle, at: sectionsTitles.startIndex)
            countries[preferredTitle] = dataSource.preferredCountries
        }
        
        if #available(iOS 13.0, *) {
            self.view.backgroundColor = .systemBackground
            tableView.backgroundColor = .systemBackground
        } else {
            self.view.backgroundColor = .clear
            tableView.backgroundColor = .clear
        }
        navigationController?.view.backgroundColor = .clear
        tableView.isOpaque = false
        tableView.backgroundView = nil
        tableView.sectionIndexBackgroundColor = .clear
        tableView.sectionIndexTrackingBackgroundColor = .clear
        
        if let selectedCountry = self.dataSource.selectedCountry(in: self.countryPickerView) {
            self.countryPickerView.selectedCountry = selectedCountry
        }
    }
    
    func prepareNavItem() {
        navigationItem.title = dataSource.navigationTitle

        // Add a close button if this is the root view controller
        if navigationController?.viewControllers.count == 1 {
            let closeButton = dataSource.closeButtonNavigationItem
            closeButton.target = self
            closeButton.action = #selector(close)
            navigationItem.leftBarButtonItem = closeButton
        }
    }
    
    func prepareSearchBar() {
        let searchBarPosition = dataSource.searchBarPosition
        if searchBarPosition == .hidden  {
            return
        }
        searchController = UISearchController(searchResultsController:  nil)
        searchController?.searchResultsUpdater = self
        searchController?.dimsBackgroundDuringPresentation = false
        searchController?.hidesNavigationBarDuringPresentation = self.dataSource?.searchBarAutohide(in: self.countryPickerView) ?? (searchBarPosition == .tableViewHeader)
        searchController?.definesPresentationContext = true
        searchController?.searchBar.delegate = self
        searchController?.delegate = self

        switch searchBarPosition {
        case .tableViewHeader: tableView.tableHeaderView = searchController?.searchBar
        case .navigationBar: navigationItem.titleView = searchController?.searchBar
        default: break
        }
    }
    
    @objc private func close() {
        self.navigationController?.dismiss(animated: true, completion: nil)
    }
}

//MARK:- UITableViewDataSource
extension CountryPickerViewController {
    
    override public func numberOfSections(in tableView: UITableView) -> Int {
        return isSearchMode ? 1 : sectionsTitles.count
    }
    
    override public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isSearchMode ? searchResults.count : countries[sectionsTitles[section]]!.count
    }
    
    override public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let identifier = String(describing: CountryTableViewCell.self)
        
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier) as? CountryTableViewCell
            ?? CountryTableViewCell(style: .default, reuseIdentifier: identifier)
        
        let country = isSearchMode ? searchResults[indexPath.row]
            : countries[sectionsTitles[indexPath.section]]![indexPath.row]

        var name = country.localizedName ?? country.name
        if dataSource.showCountryCodeInList {
            name = "\(name) (\(country.code))"
        }
        if dataSource.showPhoneCodeInList {
            name = "\(name) (\(country.phoneCode))"
        }
        cell.imageView?.image = country.flag
        
        cell.flgSize = dataSource.cellImageViewSize
        cell.imageView?.clipsToBounds = true

        cell.imageView?.layer.cornerRadius = dataSource.cellImageViewCornerRadius
        cell.imageView?.layer.masksToBounds = true
        
        cell.textLabel?.text = name
        cell.textLabel?.font = dataSource.cellLabelFont
        if let color = dataSource.cellLabelColor {
            cell.textLabel?.textColor = color
        }
        cell.accessoryType = country == countryPickerView.selectedCountry &&
            dataSource.showCheckmarkInList ? .checkmark : .none
        cell.separatorInset = .zero
        return cell
    }
    
    override public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return isSearchMode ? nil : sectionsTitles[section]
    }
    
    override public func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        if isSearchMode {
            return nil
        } else {
            if hasPreferredSection {
                return Array<String>(sectionsTitles.dropFirst())
            }
            return sectionsTitles
        }
    }
    
    override public func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        return sectionsTitles.firstIndex(of: title)!
    }
}

extension CountryPickerViewController: UITableViewDataSourcePrefetching {
    public func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        DispatchQueue.global(qos: .userInitiated).async {
            var mutableIndexPaths = indexPaths
            
            var index = 1
            repeat {
                print("\(index) vs \(max(0,(self.countries[self.sectionsTitles[indexPaths.last!.section]]!.count - indexPaths.last!.row - 2))), total count : \(self.countries[self.sectionsTitles[indexPaths.last!.section]]!.count), appending index: \(indexPaths.last!.row + index)")
                mutableIndexPaths.append(IndexPath(row: indexPaths.last!.row + index, section: indexPaths.last!.section))
                index += 1
            } while index < max(0,(self.countries[self.sectionsTitles[indexPaths.last!.section]]!.count - indexPaths.last!.row - 2)) //- 2 cuz index = 1 and count must - 1
            
            for indexPath in indexPaths {
                self.countries[self.sectionsTitles[indexPath.section]]![indexPath.row].prepareFlagIfNeeded() 
            }
        }
    }
}

//MARK:- UITableViewDelegate
extension CountryPickerViewController {

    override public func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let header = view as? UITableViewHeaderFooterView {
            header.textLabel?.font = dataSource.sectionTitleLabelFont
            if let color = dataSource.sectionTitleLabelColor {
                header.textLabel?.textColor = color
            }
        }
    }
    
    override public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let country = isSearchMode ? searchResults[indexPath.row]
            : countries[sectionsTitles[indexPath.section]]![indexPath.row]

        searchController?.dismiss(animated: false, completion: nil)
        
        let completion = {
            self.countryPickerView.selectedCountry = country
            self.countryPickerView.delegate?.countryPickerView(self.countryPickerView, didSelectCountry: country)
        }
        // If this is root, dismiss, else pop
        if navigationController?.viewControllers.count == 1 {
            navigationController?.dismiss(animated: true, completion: completion)
        } else {
            navigationController?.popViewController(animated: true, completion: completion)
        }
    }
}

// MARK:- UISearchResultsUpdating
extension CountryPickerViewController: UISearchResultsUpdating {
    public func updateSearchResults(for searchController: UISearchController) {
        isSearchMode = false
        if let text = searchController.searchBar.text, text.count > 0 {
            isSearchMode = true
            searchResults.removeAll()
            
            var indexArray = [Country]()
            
            if showOnlyPreferredSection && hasPreferredSection,
                let array = countries[dataSource.preferredCountriesSectionTitle!] {
                indexArray = array
            } else if let array = countries[String(text.capitalized[text.startIndex])] {
                indexArray = array
            }

            searchResults.append(contentsOf: indexArray.filter({
                let name = ($0.localizedName ?? $0.name).lowercased()
                let code = $0.code.lowercased()
                let query = text.lowercased()
                return name.hasPrefix(query) || (dataSource.showCountryCodeInList && code.hasPrefix(query))
            }))
        }
        tableView.reloadData()
    }
}

// MARK:- UISearchBarDelegate
extension CountryPickerViewController: UISearchBarDelegate {
    public func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        // Hide the back/left navigationItem button
        navigationItem.leftBarButtonItem = nil
        navigationItem.hidesBackButton = true
    }
    
    public func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        // Show the back/left navigationItem button
        prepareNavItem()
        navigationItem.hidesBackButton = false
    }
}

// MARK:- UISearchControllerDelegate
// Fixes an issue where the search bar goes off screen sometimes.
extension CountryPickerViewController: UISearchControllerDelegate {
    public func willPresentSearchController(_ searchController: UISearchController) {
//        self.navigationController?.navigationBar.isTranslucent = true
    }
    
    public func willDismissSearchController(_ searchController: UISearchController) {
//        self.navigationController?.navigationBar.isTranslucent = false
    }
}

// MARK:- CountryTableViewCell.
class CountryTableViewCell: UITableViewCell {
    
    var flgSize: CGSize = .zero
    
    override func layoutSubviews() {
        super.layoutSubviews()
        imageView?.frame.size = flgSize
        imageView?.center.y = contentView.center.y
    }
}

class CountryPickerViewDataSourceDefaultTempFix: CountryPickerViewDataSource {
    func selectedCountry(in countryPickerView: CountryPickerView) -> Country? {
        return nil
    }
}

// MARK:- An internal implementation of the CountryPickerViewDataSource.
// Returns default options where necessary if the data source is not set.
class CountryPickerViewDataSourceInternal: CountryPickerViewDataSource {
    private unowned var view: CountryPickerView
    
    init(view: CountryPickerView) {
        self.view = view
    }
    
    var preferredCountries: [Country] {
        return view.dataSource?.preferredCountries(in: view) ?? preferredCountries(in: view)
    }
    
    var preferredCountriesSectionTitle: String? {
        return view.dataSource?.sectionTitleForPreferredCountries(in: view)
    }
    
    var showOnlyPreferredSection: Bool {
        return view.dataSource?.showOnlyPreferredSection(in: view) ?? showOnlyPreferredSection(in: view)
    }
    
    var sectionTitleLabelFont: UIFont {
        return view.dataSource?.sectionTitleLabelFont(in: view) ?? sectionTitleLabelFont(in: view)
    }

    var sectionTitleLabelColor: UIColor? {
        return view.dataSource?.sectionTitleLabelColor(in: view)
    }
    
    var cellLabelFont: UIFont {
        return view.dataSource?.cellLabelFont(in: view) ?? cellLabelFont(in: view)
    }
    
    var cellLabelColor: UIColor? {
        return view.dataSource?.cellLabelColor(in: view)
    }
    
    var cellImageViewSize: CGSize {
        return view.dataSource?.cellImageViewSize(in: view) ?? cellImageViewSize(in: view)
    }
    
    var cellImageViewCornerRadius: CGFloat {
        return view.dataSource?.cellImageViewCornerRadius(in: view) ?? cellImageViewCornerRadius(in: view)
    }
    
    var navigationTitle: String? {
        return view.dataSource?.navigationTitle(in: view)
    }
    
    var closeButtonNavigationItem: UIBarButtonItem {
        guard let button = view.dataSource?.closeButtonNavigationItem(in: view) else {
            return UIBarButtonItem(title: "Close", style: .done, target: nil, action: nil)
        }
        return button
    }
    
    var searchBarPosition: SearchBarPosition {
        return view.dataSource?.searchBarPosition(in: view) ?? searchBarPosition(in: view)
    }
    
    func searchBarAutohide(in countryPickerView: CountryPickerView) -> Bool {
        return view.dataSource?.searchBarAutohide(in: view) ?? searchBarAutohide(in: view)
    }
    
    var showPhoneCodeInList: Bool {
        return view.dataSource?.showPhoneCodeInList(in: view) ?? showPhoneCodeInList(in: view)
    }
    
    var showCountryCodeInList: Bool {
        return view.dataSource?.showCountryCodeInList(in: view) ?? showCountryCodeInList(in: view)
    }
    
    var showCheckmarkInList: Bool {
        return view.dataSource?.showCheckmarkInList(in: view) ?? showCheckmarkInList(in: view)
    }
    
    func preferredStatusBarStyle(in countryPickerView: CountryPickerView) -> UIStatusBarStyle {
        return view.dataSource?.preferredStatusBarStyle(in: view) ?? preferredStatusBarStyle(in: view)
    }
    
    func selectedCountry(in countryPickerView: CountryPickerView) -> Country? {
        return view.dataSource?.selectedCountry(in: view) ?? CountryPickerViewDataSourceDefaultTempFix().selectedCountry(in: view)
    }
}
