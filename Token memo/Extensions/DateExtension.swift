//
//  DateExtension.swift
//  Token memo
//
//  Created by Leeo on 12/11/25.
//

import Foundation

extension Date {
    func toString(format: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format
        return dateFormatter.string(from: self)
    }
}
