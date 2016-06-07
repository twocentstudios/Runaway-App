//
//  Settings.swift
//  processalert
//
//  Created by Christopher Trott on 6/7/16.
//  Copyright © 2016 twocentstudios. All rights reserved.
//

import Foundation

struct Settings {
    let numberOfSamples: Int
    let cpuThreshold: CPUPercentage // 50.0 = 50.0%
    let delay: NSTimeInterval // seconds
    let remainingSamples: Int
    let alertThresholdMinutes: Int
    
    init(numberOfSamples: Int = 6, cpuThreshold: CPUPercentage = 50.0, delay: NSTimeInterval = 3, remainingSamples: Int = 30, alertThresholdMinutes: Int = 30) {
        self.numberOfSamples = numberOfSamples
        self.cpuThreshold = cpuThreshold
        self.delay = delay
        self.remainingSamples = remainingSamples
        self.alertThresholdMinutes = alertThresholdMinutes
    }
}
