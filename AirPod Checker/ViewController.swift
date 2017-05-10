//
//  ViewController.swift
//  AirPod Checker
//
//  Created by Tobias Scholze on 10.05.17.
//  Copyright © 2017 Tobias Scholze. All rights reserved.
//

import Cocoa
import Alamofire


class ViewController: NSViewController
{
    // MARK: - Outlets -
    
    @IBOutlet private weak var tableView    : NSTableView!
    @IBOutlet private weak var refreshButton: NSButton!
    
    
    // MARK: - Private constants -
    
    private let zipSouth = "86150"
    private let zipNorth = "20095"
    private let url = "https://www.apple.com/de/shop/retail/pickup-message?parts.0=MMEF2ZM%2FA&location="
    
    
    // MARK: - Private properties -
    
    fileprivate var entries = [AvailableModel]()
    
    private let shortDateFormatter = { (Void) -> DateFormatter in
        let formatter           = DateFormatter()
        formatter.dateFormat    = "d MMM yyyy"
        formatter.locale        = Locale(identifier: "en")
        return formatter
    }()
    

    // MARK: - View life cycle -
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        tableView.dataSource    = self
        tableView.delegate      = self
        
        refeshEntries() {
            self.tableView.reloadData()
        }
    }
    
    
    // MARK: - Actions -
    
    @IBAction func handleRefreshButtonTapped(_ sender: Any)
    {
        refeshEntries() {
            self.tableView.reloadData()
        }
    }
    
    
    // MARK: - Private helper -
    
    private func refeshEntries(completion: @escaping () -> ())
    {
        refreshButton.isEnabled = false
        
        retrieveStatusByZip(zip: zipSouth) {[weak self] (southEntries) in
            
            guard let _self = self else
            {
                return
            }
            
            _self.entries = southEntries
            
            _self.retrieveStatusByZip(zip: _self.zipNorth) { (northEntries) in
                for entry in northEntries
                {
                    if _self.entries.contains(where: {$0.name == entry.name})
                    {
                        continue
                    }
                    
                    _self.entries.append(entry)
                }
                
                // Sort entries
                _self.entries.sort(by: { $0.city < $1.city})
                
                _self.tableView.reloadData()
                _self.refreshButton.isEnabled = true
            }
        }
    }
    
    
    private func retrieveStatusByZip(zip: String, completion: @escaping ([AvailableModel]) -> ())
    {
        var foundEntries = [AvailableModel]()
        
        Alamofire.request(url + zip).responseJSON {[weak self] response in
            
            guard let _self = self else
            {
                return
            }
            
            guard let json = response.result.value as? [String: Any] else
            {
                return
            }
            
            guard let body = json["body"] as? [String : Any],
                let stores = body["stores"] as? [[String: Any]] else
            {
                print("Nothing found")
                return
            }
            
            for store in stores
            {
                guard let name = store["storeName"] as? String,
                    let city = store["city"] as? String,
                    let available = store["partsAvailability"] as? [String: Any],
                    let part = available["MMEF2ZM/A"] as? [String: Any],
                    let availableDateString = part["pickupSearchQuote"] as? String else
                {
                    continue
                }
                
                // Ignore alreade added stores
                if _self.entries.contains(where: {$0.name == name})
                {
                    continue
                }
                
                // Post process
                let trimmedData = availableDateString.replacingOccurrences(of: "Verfügbar<br/>", with: "")
                guard let availableDate = _self.shortDateFormatter.date(from: "\(trimmedData) 2017") else
                {
                    print("Skipping entry for store: \(name)")
                    continue
                }
                
                foundEntries.append(AvailableModel(name: name, city: city, availableDate: availableDate))
            }
            
           completion(foundEntries)
        }
    }
}

// MARK: - NSTableViewDelegate -

extension ViewController: NSTableViewDelegate
{
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView?
    {
        guard let identifier = tableColumn?.identifier else
        {
            return nil
        }
        
        let selectedEntry = entries[row]
        
        guard let cell = tableView.make(withIdentifier: identifier, owner: nil) as? NSTableCellView else
        {
            return nil
        }
        
        if identifier == "store"
        {
            cell.textField?.stringValue = selectedEntry.name
        }
            
        else if identifier == "city"
        {
            cell.textField?.stringValue = selectedEntry.city
        }
            
        else if identifier == "days"
        {
            var value = ""
            
            if selectedEntry.availableInDays == 0
            {
                value = "heute"
            }
                
            else if selectedEntry.availableInDays == 1
            {
                value = "morgen"
            }
                
            else
            {
                guard let dayString = selectedEntry.availableInDays else
                {
                    return nil
                }
                
                value = "in \(dayString) Tagen"
            }
            
            cell.textField?.stringValue = value
        }
        
        return cell
    }
}

// MARK: - NSTableViewDataSource -

extension ViewController: NSTableViewDataSource
{
    func numberOfRows(in tableView: NSTableView) -> Int
    {
        return entries.count
    }
}


// MARK: - AvailableModel -

class AvailableModel
{
    // MARK: - Internal properties -
    
    var name            : String!
    var city            : String!
    var availableDate   : Date!
    var availableInDays : Int!
    
    
    // MARK - Init -
    
    init(name: String, city: String, availableDate: Date)
    {
        self.name               = name
        self.city               = city
        self.availableDate      = availableDate
        self.availableInDays    = Date().time(toDate: availableDate, inUnit: .day)
    }
}


// MARK: - Date extension -

extension Date
{
    func time(toDate date: Date, inUnit unit: Calendar.Component) -> Int?
    {
        let difference = Calendar.current.dateComponents(Set(arrayLiteral: unit), from: self, to: date)
        return difference.value(for: unit)
    }
}

