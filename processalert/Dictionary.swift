//
//  Dictionary.swift
//  processalert
//
//  Created by Christopher Trott on 6/7/16.
//  Copyright © 2016 twocentstudios. All rights reserved.
//

import Foundation

extension Dictionary {
    init(_ pairs: [Element]) {
        self.init()
        for (k, v) in pairs {
            self[k] = v
        }
    }
}