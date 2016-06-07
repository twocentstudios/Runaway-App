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
    
    let numberOfSamples = 6
    let cpuThreshold = 50.0
    let delay: NSTimeInterval = 3 // seconds
    let remainingSamples = 30
    let alertThresholdMinutes = 30
    var processes: ProcessHash = [:]
    
    var timer: RepeatingTimer!

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        timer = RepeatingTimer(interval: delay, leeway: 0, queue: dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0)) { [unowned self] in
            self.processes = self.tick(self.processes)
        }
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        timer.cancel()
    }
    
    private func tick(processes: ProcessHash) -> ProcessHash {
        let notificationCenter = NSUserNotificationCenter.defaultUserNotificationCenter()
        let psOutput = shell(ProcessStatus.launchPath, arguments: ProcessStatus.arguments)
        let rawProcesses = ProcessStatus.parse(psOutput)
        let mergedProcesses = mergeRawProcesses(processes, rawProcesses: rawProcesses)
        let filtered = filterLatestSamples(mergedProcesses, numberOfSamples: numberOfSamples, threshold: cpuThreshold)
        let updatedProcesses = sendNotifications(mergedProcesses, overProcesses: filtered, notificationCenter: notificationCenter)
        let prunedSamplesFromProcesses = pruneSamples(updatedProcesses, remainingSamples: remainingSamples)
        return prunedSamplesFromProcesses
    }
    
    private func sendNotifications(processes: ProcessHash, overProcesses: [ProcessID: CPUPercentage], notificationCenter: NSUserNotificationCenter) -> ProcessHash {
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
                cpuLoad: cpuLoad)
            pendingNotifications.append(notification)
            
            // Update process lastAlertAt
            process.lastAlertAt = now
            updatedProcesses[processId] = process
            
            print(processes[processId])
        }
        
        // Deliver notifications
        pendingNotifications.forEach { notificationCenter.deliverNotification($0) }
        
        return updatedProcesses
    }
    
    private func createUserNotification(processName: String, averagedTimePeriod: NSTimeInterval, cpuLoad: CPUPercentage) -> NSUserNotification {
        let notificationTitle = "\(processName) using over \(cpuThreshold)% CPU"
        let notificationText = "Average \(cpuLoad)% CPU for the last \(Int(averagedTimePeriod)) seconds."
        let notification = NSUserNotification()
        notification.title = notificationTitle
        notification.informativeText = notificationText
        return notification
    }
}

