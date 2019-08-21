//
//  DateFormatter.swift
//  GpxExport
//
//  Created by Patrick Steiner on 21.08.19.
//  Copyright © 2019 Mario Martelli. All rights reserved.
//

import Foundation

extension DateFormatter {
    static var exportFileFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"

        return formatter
    }
}
