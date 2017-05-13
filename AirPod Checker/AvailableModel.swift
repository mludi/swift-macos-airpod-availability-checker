//
//  AvailableModel.swift
//  AirPod Checker
//
//  Created by Matthias Ludwig on 13.05.17.
//  Copyright © 2017 Tobias Scholze. All rights reserved.
//

import Foundation

// MARK: - AvailableModel -

struct AvailableModel
{
    // MARK: - Internal properties -
    
    let name            : String
    let city            : String
    let availableDate   : Date
    let availableInDays : Int?
    
    
    // MARK - Init -
    
    init(name: String, city: String, availableDate: Date)
    {
        self.name               = name
        self.city               = city
        self.availableDate      = availableDate.startOfDay
        
        let today               = Date().startOfDay
        
        self.availableInDays    = today.time(toDate: availableDate, inUnit: .day)
    }
}
