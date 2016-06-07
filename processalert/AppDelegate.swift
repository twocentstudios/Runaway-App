//
//  AppDelegate.swift
//  processalert
//
//  Created by Christopher Trott on 6/3/16.
//  Copyright © 2016 twocentstudios. All rights reserved.
//

import Cocoa

typealias CPUPercentage = Double
typealias ProcessID = Int
typealias ProcessHash = [ProcessID: Process]
typealias RawProcesses = [RawProcess]

// ps -acwwwxo pid="",pcpu="",command=""

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    
    let numberOfSamples = 6
    let cpuThreshold = 50.0
    let delay: NSTimeInterval = 3 // seconds
    let remainingSamples = 30
    let alertThresholdMinutes = 30
    var processes: ProcessHash = [:]
    
    var timer: dispatch_source_t!

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        
        timer = repeatingTimer(delay, leeway: 0, queue: dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0)) { [unowned self] in
            self.processes = self.tick(self.processes)
        }
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        dispatch_source_cancel(timer);
    }
    
    private func shell(launchPath: String, arguments: [String]) -> String {
        let task = NSTask()
        task.launchPath = launchPath
        task.arguments = arguments
        
        let pipe = NSPipe()
        task.standardOutput = pipe
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output: String = NSString(data: data, encoding: NSUTF8StringEncoding)! as String
        
        return output
    }
    
    private func parseProcessStatus(input: String) -> RawProcesses {
        let rawProcesses = input
            .componentsSeparatedByString("\n")
            .filter({ !$0.isEmpty })
            .map { line -> RawProcess in
                let components = line.componentsSeparatedByString(" ").filter({ !$0.isEmpty })
                let pid = Int(components[0])!
                let sample = CPUPercentage(components[1])!
                let name = components.suffixFrom(2).reduce("", combine:{ $0 + " " + $1 })
                let process = RawProcess(processId: pid, name: name, sample: sample)
                return process
            }
        return rawProcesses
    }
    
    private func mergeRawProcesses(rawProcesses: RawProcesses, processes: ProcessHash) -> ProcessHash {
        var outProcesses = processes
        for rawProcess in rawProcesses {
            if let process = outProcesses[rawProcess.processId] {
                var outProcess = process
                outProcess.appendSample(rawProcess.sample)
                outProcesses[outProcess.processId] = outProcess
            } else {
                let outProcess = Process(rawProcess: rawProcess)
                outProcesses[outProcess.processId] = outProcess
            }
        }
        // TODO: remove quit processes
        return outProcesses
    }
    
    private func tick(processes: ProcessHash) -> ProcessHash {
        let notificationCenter = NSUserNotificationCenter.defaultUserNotificationCenter()
        let psOutput = shell("/bin/ps", arguments: ["-acwwwxo", "pid=,pcpu=,command="])
        let rawProcesses = parseProcessStatus(psOutput)
        let mergedProcesses = mergeRawProcesses(rawProcesses, processes: processes)
        let filtered = filterLatestSamples(mergedProcesses, numberOfSamples: numberOfSamples, threshold: cpuThreshold)
        let updatedProcesses = sendNotifications(mergedProcesses, overProcesses: filtered, notificationCenter: notificationCenter)
        let prunedSamplesFromProcesses = pruneSamples(updatedProcesses, remainingSamples: remainingSamples)
        return prunedSamplesFromProcesses
    }
    
    // Returns the average load for processes where all latest samples are above the provided threshold.
    private func filterLatestSamples(processes: ProcessHash, numberOfSamples: Int, threshold: CPUPercentage) -> [ProcessID: CPUPercentage] {
        let processLoadArray = processes
            .map { (processId: ProcessID, process: Process) -> (ProcessID, [CPUPercentage]) in
                let truncatedSamples = Array(process.samples.suffix(numberOfSamples))
                return (processId, truncatedSamples)
            }
            .filter({ $1.count == numberOfSamples })
            .filter({ (processID: ProcessID, samples: [CPUPercentage]) -> Bool in
                let allSamplesGreaterThanThreshold = samples.reduce(true, combine: { $0 && ($1 >= threshold)})
                return allSamplesGreaterThanThreshold
            })
            .map { (processID: ProcessID, samples: [CPUPercentage]) -> (ProcessID, CPUPercentage) in
                let total = samples.reduce(0, combine: +)
                let count = samples.count
                let average = total / Double(count)
                return (processID, average)
            }
        return Dictionary(processLoadArray)
    }
    
    private func getProcessName(processes: ProcessHash, processId: ProcessID) -> String {
        guard let process = processes[processId] else { fatalError("processId not contained in processes hash") }
        return process.name
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
    
    private func pruneSamples(processes: ProcessHash, remainingSamples: Int) -> ProcessHash {
        let processesArray = processes.map { (processId: ProcessID, process: Process) -> (ProcessID, Process) in
            var outProcess = process
            outProcess.pruneSamples(remainingSamples)
            return (processId, outProcess)
        }
        let outProcesses = Dictionary(processesArray)
        return outProcesses
    }
    
    private func repeatingTimer(interval: NSTimeInterval, leeway: NSTimeInterval, start: dispatch_time_t = DISPATCH_TIME_NOW, queue: dispatch_queue_t = dispatch_get_main_queue(), action: dispatch_block_t) -> dispatch_source_t {
        let timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue)
        guard timer != nil else { fatalError("Could not create timer.") }
        
        func nanoseconds(seconds: NSTimeInterval) -> UInt64 {
            enum Static { static let Multiplier = Double(NSEC_PER_SEC) }
            
            return UInt64(seconds * Static.Multiplier)
        }
        
        dispatch_source_set_event_handler(timer, action)
        dispatch_source_set_timer(timer, start, nanoseconds(interval), nanoseconds(leeway))
        
        dispatch_resume(timer)
        
        return timer
    }
}

struct RawProcess {
    let processId: ProcessID
    let name: String
    let sample: CPUPercentage
}

struct Process {
    let processId: ProcessID
    let name: String
    var samples: [CPUPercentage] // TODO: Possibly created bounded FIFO queue
    var lastAlertAt: NSDate?
}

extension Process {
    init(rawProcess: RawProcess) {
        self.processId = rawProcess.processId
        self.name = rawProcess.name
        self.samples = [rawProcess.sample]
        self.lastAlertAt = nil
    }
    
    mutating func appendSample(sample: CPUPercentage) {
        self.samples.append(sample)
    }
    
    mutating func pruneSamples(remainingSamples: Int) {
        if remainingSamples <= 0 { return }
        if self.samples.count <= remainingSamples { return }
        self.samples = Array(self.samples.suffix(remainingSamples))
    }
    
    func shouldSendNotification(currentTime: NSDate, thresholdMinutes: Int) -> Bool {
        guard let lastAlertAt = self.lastAlertAt else { return true }
        let thresholdSeconds = NSTimeInterval(thresholdMinutes * 60)
        return currentTime.timeIntervalSinceDate(lastAlertAt) > thresholdSeconds
    }
}

extension Dictionary {
    init(_ pairs: [Element]) {
        self.init()
        for (k, v) in pairs {
            self[k] = v
        }
    }
}