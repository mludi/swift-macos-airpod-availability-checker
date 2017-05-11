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
    
    @IBOutlet fileprivate weak var tableView    : NSTableView!
    @IBOutlet private weak var refreshButton    : NSButton!
    @IBOutlet private weak var progressIndicator: NSProgressIndicator!
    
    
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
        
        refreshEntries()
    }
    
    
    // MARK: - Actions -
    
    @IBAction func handleRefreshButtonTapped(_ sender: Any)
    {
        refreshEntries()
    }
    
    
    // MARK: - Private helper -
    
    private func refreshEntries()
    {
        refreshButton.isEnabled = false
        progressIndicator.startAnimation(nil)
        
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
                _self.progressIndicator.stopAnimation(false)
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
    
    
    fileprivate func suffixStringForDaysUntilAvailable(entry: AvailableModel) -> String
    {
        if entry.availableInDays == 0
        {
            return "heute"
        }
            
        else if entry.availableInDays == 1
        {
            return "morgen"
        }
            
        else
        {
            guard let dayString = entry.availableInDays else
            {
                return ""
            }
            
            return  "in \(dayString) Tagen"
        }
    }
    
    
    fileprivate func postTweet()
    {
        let selectedEntry   = entries[tableView.selectedRow]
        let suffix          = suffixStringForDaysUntilAvailable(entry: selectedEntry)
        let message         = "Der Apple Store \(selectedEntry.name ?? "") hat \(suffix) AirPods vorrätig."
        let service         = NSSharingService(named: NSSharingServiceNamePostOnTwitter)
        service?.delegate   = self
        
        service?.perform(withItems: [message])
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
            cell.textField?.stringValue = suffixStringForDaysUntilAvailable(entry: selectedEntry)
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


// MARK: - NSSharingServiceDelegate -

extension ViewController: NSSharingServiceDelegate
{
    
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

