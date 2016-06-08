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
    let updateInterval: NSTimeInterval // seconds
    let remainingSamples: Int
    let alertThresholdMinutes: Int
    
    init(numberOfSamples: Int = 6, cpuThreshold: CPUPercentage = 50.0, updateInterval: NSTimeInterval = 3, remainingSamples: Int = 30, alertThresholdMinutes: Int = 30) {
        self.numberOfSamples = numberOfSamples
        self.cpuThreshold = cpuThreshold
        self.updateInterval = updateInterval
        self.remainingSamples = remainingSamples
        self.alertThresholdMinutes = alertThresholdMinutes
    }
}

extension Settings {
    static let numberOfSamplesKey = "numberOfSamples"
    static let cpuThresholdKey = "cpuThreshold"
    static let updateIntervalKey = "updateInterval"
    static let alertThresholdKey = "alertThreshold"
    
    init(defaults: NSUserDefaults) {
        self.numberOfSamples = defaults.integerForKey(Settings.numberOfSamplesKey)
        self.cpuThreshold = defaults.doubleForKey(Settings.cpuThresholdKey)
        self.updateInterval = NSTimeInterval(defaults.integerForKey(Settings.updateIntervalKey))
        self.remainingSamples = self.numberOfSamples
        self.alertThresholdMinutes = defaults.integerForKey(Settings.alertThresholdKey)
    }
    
    func writeToDefaults(defaults: NSUserDefaults) {
        defaults.setDouble(self.cpuThreshold, forKey: Settings.cpuThresholdKey)
        defaults.setDouble(self.updateInterval, forKey: Settings.updateIntervalKey)
        defaults.setInteger(self.numberOfSamples, forKey: Settings.numberOfSamplesKey)
        defaults.setInteger(self.alertThresholdMinutes, forKey: Settings.alertThresholdKey)
    }
    
    static func writeInitialDefaults(defaults: NSUserDefaults) {
        let settings = Settings()
        let dictionary: [String: AnyObject] =
            [ Settings.cpuThresholdKey: settings.cpuThreshold,
              Settings.updateIntervalKey: settings.updateInterval,
              Settings.numberOfSamplesKey: settings.numberOfSamples,
              Settings.alertThresholdKey: settings.alertThresholdMinutes ]
        defaults.registerDefaults(dictionary)
    }
}