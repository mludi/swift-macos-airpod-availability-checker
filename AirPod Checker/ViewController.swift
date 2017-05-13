//
//  ViewController.swift
//  AirPod Checker
//
//  Created by Tobias Scholze on 10.05.17.
//  Copyright © 2017 Tobias Scholze. All rights reserved.
//

import Cocoa

typealias JSONDictionary = [String: Any]
typealias JSONArray = [JSONDictionary]

class ViewController: NSViewController
{
    // MARK: - Outlets -
    
    @IBOutlet fileprivate weak var tableView    : NSTableView!
    @IBOutlet private weak var refreshButton    : NSButton!
    @IBOutlet private weak var progressIndicator: NSProgressIndicator!
    
    
    // MARK: - Private constants -
    
    private let zipSouth    = "86150"
    private let zipNorth    = "20095"
    private let jsonUrl     = "https://www.apple.com/de/shop/retail/pickup-message?parts.0=MMEF2ZM%2FA&location="
    private let storeUrl    = "https://www.apple.com/de/shop/product/MMEF2ZM/A/airpods"
    
    
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
    
    
    @IBAction func handleGoToStoreButtonTapped(_ sender: Any)
    {
        guard let url = URL(string: storeUrl) else
        {
            return
        }
        
        NSWorkspace.shared().open(url)
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
                DispatchQueue.main.async {
                    _self.tableView.reloadData()
                    _self.refreshButton.isEnabled = true
                    _self.progressIndicator.stopAnimation(false)                    
                }
            }
        }
    }
    
    
    private func retrieveStatusByZip(zip: String, completion: @escaping ([AvailableModel]) -> ())
    {
        var foundEntries = [AvailableModel]()
        
        guard let url = URL(string: "\(jsonUrl)\(zip)") else { return }
        URLSession.shared.dataTask(with: URLRequest(url: url)) { [weak self] data, response, error in
            if let error = error
            {
                print("something went wrong: \(error)")
                return
            }
            if let response = response as? HTTPURLResponse, response.statusCode == 200, let data = data
            {
                guard
                    let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: AnyObject],
                    let unwrappedJson = json
                else
                {
                    return
                }
                guard
                    let body = unwrappedJson["body"] as? JSONDictionary,
                    let stores = body["stores"] as? JSONArray
                else
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
                    guard let availableDate = self?.shortDateFormatter.date(from: "\(trimmedData) 2017") else
                    {
                        print("Skipping entry for store: \(name)")
                        continue
                    }
                    
                    foundEntries.append(AvailableModel(name: name, city: city, availableDate: availableDate))
                }
                completion(foundEntries)                
            }
        }.resume()
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
        let message         = "Der Apple Store \(selectedEntry.name) hat \(suffix) AirPods vorrätig."
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
