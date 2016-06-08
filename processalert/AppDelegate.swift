//
//  AppDelegate.swift
//  processalert
//
//  Created by Christopher Trott on 6/3/16.
//  Copyright © 2016 twocentstudios. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var settings = Settings()
    var processes: ProcessHash = [:]
    
    var timer: RepeatingTimer?

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        
        let userDefaults = NSUserDefaults.standardUserDefaults()
        Settings.writeInitialDefaults(userDefaults)
        let settings = Settings(defaults: userDefaults)
        
        let userNotificationCenter = NSUserNotificationCenter.defaultUserNotificationCenter()
        startTimer(settings, userNotificationCenter: userNotificationCenter)
        
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.addObserverForName(NSUserDefaultsDidChangeNotification, object: nil, queue: nil) { [weak self] _ in
            let updatedSettings = Settings(defaults: userDefaults)
            self?.startTimer(updatedSettings, userNotificationCenter: userNotificationCenter)
        }
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        timer?.cancel()
    }
    
    func startTimer(settings: Settings, userNotificationCenter: NSUserNotificationCenter) {
        timer?.cancel()
        timer = RepeatingTimer(interval: settings.updateInterval, leeway: 0, queue: dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0)) { [unowned self] in
            let (updatedProcesses, pendingNotifications) = self.tick(self.processes, settings: self.settings)
            
            self.processes = updatedProcesses
            
            pendingNotifications.forEach { userNotificationCenter.deliverNotification($0) }
        }
    }
    
    @IBAction func quitClicked(sender: NSMenuItem) {
        NSApplication.sharedApplication().terminate(self)
    }
    
    private func tick(processes: ProcessHash, settings: Settings) -> (ProcessHash, [NSUserNotification]) {
        let psOutput = shell(ProcessStatus.launchPath, arguments: ProcessStatus.arguments)
        let rawProcesses = ProcessStatus.parse(psOutput)
        let mergedProcesses = mergeRawProcesses(processes, rawProcesses: rawProcesses)
        let filtered = filterLatestSamples(mergedProcesses, numberOfSamples: settings.numberOfSamples, threshold: settings.cpuThreshold)
        let (updatedProcesses, pendingNotifications) = outgoingNotifications(mergedProcesses, overProcesses: filtered, alertThresholdMinutes: settings.alertThresholdMinutes, updateInterval: settings.updateInterval, numberOfSamples: settings.numberOfSamples, cpuThreshold: settings.cpuThreshold)
        let prunedSamplesFromProcesses = pruneSamples(updatedProcesses, remainingSamples: settings.remainingSamples)
        
        return (prunedSamplesFromProcesses, pendingNotifications)
    }
    
    private func outgoingNotifications(processes: ProcessHash, overProcesses: [ProcessID: CPUPercentage], alertThresholdMinutes: Int, updateInterval: NSTimeInterval, numberOfSamples: Int, cpuThreshold: CPUPercentage) -> (ProcessHash, [NSUserNotification]) {
        let now = NSDate()
        var updatedProcesses = processes
        var pendingNotifications: [NSUserNotification] = []
        for (processId, cpuLoad) in overProcesses {
            guard var process = processes[processId] else { print("Error finding runaway process \(processId)"); continue }
            if !process.shouldSendNotification(now, thresholdMinutes: alertThresholdMinutes) { print("Ignored alert for process \(processId)"); continue }
            
            // Configure local notification
            let notification = createUserNotification(
                getProcessName(processes, processId: processId),
                averagedTimePeriod: updateInterval * Double(numberOfSamples),
                cpuLoad: cpuLoad,
                cpuThreshold: cpuThreshold)
            pendingNotifications.append(notification)
            
            // Update process lastAlertAt
            process.lastAlertAt = now
            updatedProcesses[processId] = process
        }
        
        return (updatedProcesses, pendingNotifications)
    }
    
    private func createUserNotification(processName: String, averagedTimePeriod: NSTimeInterval, cpuLoad: CPUPercentage, cpuThreshold: CPUPercentage) -> NSUserNotification {
        let cpuString = String(format:"%.1f", cpuLoad)
        let notificationTitle = "\(processName) using over \(cpuThreshold)% CPU"
        let notificationText = "Average \(cpuString)% CPU for the last \(Int(averagedTimePeriod)) seconds. "
        let notification = NSUserNotification()
        notification.title = notificationTitle
        notification.informativeText = notificationText
        return notification
    }
}

