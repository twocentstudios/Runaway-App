//
//  AppDelegate.swift
//  processalert
//
//  Created by Christopher Trott on 6/3/16.
//  Copyright © 2016 twocentstudios. All rights reserved.
//

import Cocoa

typealias RawProcesses = [RawProcess]

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    
    var settings = Settings()
    var processes: ProcessHash = [:]
    
    var timer: RepeatingTimer!

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        let notificationCenter = NSUserNotificationCenter.defaultUserNotificationCenter()
        
        timer = RepeatingTimer(interval: settings.delay, leeway: 0, queue: dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0)) { [unowned self] in
            let (updatedProcesses, pendingNotifications) = self.tick(self.processes, settings: self.settings)
            
            self.processes = updatedProcesses
            
            pendingNotifications.forEach { notificationCenter.deliverNotification($0) }
        }
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        timer.cancel()
    }
    
    private func tick(processes: ProcessHash, settings: Settings) -> (ProcessHash, [NSUserNotification]) {
        let psOutput = shell(ProcessStatus.launchPath, arguments: ProcessStatus.arguments)
        let rawProcesses = ProcessStatus.parse(psOutput)
        let mergedProcesses = mergeRawProcesses(processes, rawProcesses: rawProcesses)
        let filtered = filterLatestSamples(mergedProcesses, numberOfSamples: settings.numberOfSamples, threshold: settings.cpuThreshold)
        let (updatedProcesses, pendingNotifications) = outgoingNotifications(mergedProcesses, overProcesses: filtered, alertThresholdMinutes: settings.alertThresholdMinutes, delay: settings.delay, numberOfSamples: settings.numberOfSamples, cpuThreshold: settings.cpuThreshold)
        let prunedSamplesFromProcesses = pruneSamples(updatedProcesses, remainingSamples: settings.remainingSamples)
        
        return (prunedSamplesFromProcesses, pendingNotifications)
    }
    
    private func outgoingNotifications(processes: ProcessHash, overProcesses: [ProcessID: CPUPercentage], alertThresholdMinutes: Int, delay: NSTimeInterval, numberOfSamples: Int, cpuThreshold: CPUPercentage) -> (ProcessHash, [NSUserNotification]) {
        let now = NSDate()
        var updatedProcesses = processes
        var pendingNotifications: [NSUserNotification] = []
        for (processId, cpuLoad) in overProcesses {
            guard var process = processes[processId] else { print("Error finding runaway process \(processId)"); continue }
            if !process.shouldSendNotification(now, thresholdMinutes: alertThresholdMinutes) { print("Ignored alert for process \(processId)"); continue }
            
            // Configure local notification
            let notification = createUserNotification(
                getProcessName(processes, processId: processId),
                averagedTimePeriod: delay * Double(numberOfSamples),
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
        let notificationTitle = "\(processName) using over \(cpuThreshold)% CPU"
        let notificationText = "Average \(cpuLoad)% CPU for the last \(Int(averagedTimePeriod)) seconds."
        let notification = NSUserNotification()
        notification.title = notificationTitle
        notification.informativeText = notificationText
        return notification
    }
}

