//
//  PreferencesWindow.swift
//  processalert
//
//  Created by Christopher Trott on 6/7/16.
//  Copyright © 2016 twocentstudios. All rights reserved.
//

import Cocoa

class PreferencesWindow: NSWindowController, NSWindowDelegate {
    
    @IBOutlet weak var cpuSlider: NSSlider!
    @IBOutlet weak var cpuLabel: NSTextField!
    
    @IBOutlet weak var updateIntervalSlider: NSSlider!
    @IBOutlet weak var updateIntervalLabel: NSTextField!
    
    @IBOutlet weak var alertAfterSlider: NSSlider!
    @IBOutlet weak var alertAfterLabel: NSTextField!
    
    @IBOutlet weak var resetAfterSlider: NSSlider!
    @IBOutlet weak var resetAfterLabel: NSTextField!
    
    let defaults = NSUserDefaults.standardUserDefaults()
    
    override var windowNibName : String! {
        return "PreferencesWindow"
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()

        loadSettings(defaults)
        updateLabels()
        
        self.window?.center()
        self.window?.makeKeyAndOrderFront(nil)
        NSApp.activateIgnoringOtherApps(true)
    }
    
    func windowWillClose(notification: NSNotification) {
        writeSettings(defaults)
    }
    
    private func loadSettings(defaults: NSUserDefaults) {
        let settings = Settings(defaults: defaults)
        cpuSlider.doubleValue = settings.cpuThreshold
        updateIntervalSlider.doubleValue = settings.updateInterval
        alertAfterSlider.integerValue = settings.numberOfSamples
        resetAfterSlider.integerValue = settings.alertThresholdMinutes
    }
    
    private func writeSettings(defaults: NSUserDefaults) {
        let settings = Settings(
            numberOfSamples: alertAfterSlider.integerValue,
            cpuThreshold: cpuSlider.doubleValue,
            updateInterval: updateIntervalSlider.doubleValue,
            alertThresholdMinutes: resetAfterSlider.integerValue)
        settings.writeToDefaults(defaults)
    }
    
    private func updateLabels() {
        cpuLabel.stringValue = "\(cpuSlider.doubleValue)%"
        updateIntervalLabel.stringValue = "\(updateIntervalSlider.integerValue) sec"
        let alertAfter = alertAfterTime(updateIntervalSlider.integerValue, samples: alertAfterSlider.integerValue)
        alertAfterLabel.stringValue = "\(alertAfter) sec"
        resetAfterLabel.stringValue = "\(resetAfterSlider.integerValue) min"
    }
    
    @IBAction func cpuSliderChanged(sender: NSSlider) {
        updateLabels()
    }
    
    @IBAction func updateIntervalSliderChanged(sender: NSSlider) {
        updateLabels()
    }
    
    @IBAction func alertAfterSliderChanged(sender: NSSlider) {
        updateLabels()
    }
    
    @IBAction func resetAfterSliderChanged(sender: NSSlider) {
        updateLabels()
    }
    
    private func alertAfterTime(updateInterval: Int, samples: Int) -> Int {
        return updateInterval * samples
    }
    
}
