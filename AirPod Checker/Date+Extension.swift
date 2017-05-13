//
//  Date+Extension.swift
//  AirPod Checker
//
//  Created by Matthias Ludwig on 13.05.17.
//  Copyright © 2017 Tobias Scholze. All rights reserved.
//

import Foundation

// MARK: - Date extension -

extension Date
{
    // MARK: - Computed properties -
    
    var startOfDay: Date
    {
        return Calendar.current.startOfDay(for: self)
    }
    
    
    // MARK: - Helpers -
    
    func time(toDate date: Date, inUnit unit: Calendar.Component) -> Int?
    {
        let difference = Calendar.current.dateComponents(Set(arrayLiteral: unit), from: self, to: date)
        return difference.value(for: unit)
    }
}
