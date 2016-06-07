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

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    
    let numberOfAveragedSamples = 10
    let cpuThreshold = 0.5
    let delay: Int = 3 // seconds
    let remainingSamples = 10
    var processes: ProcessHash = [:]

    func applicationDidFinishLaunching(aNotification: NSNotification) {

        while(true) {
            self.processes = tick(processes)
            sleep(UInt32(delay))
        }
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }
    
    private func tick(processes: ProcessHash) -> ProcessHash {
        let notificationCenter = NSUserNotificationCenter.defaultUserNotificationCenter()
        let runningApplications = getRunningApplications()
        let merged = mergeApplications(processes, applications: runningApplications)
        let addedSamplesArray = merged.map { (processId: ProcessID, process: Process) -> (ProcessID, Process) in
            let cpuPercentage = getProcessCPUPercentage(processId)
            var updatedProcess = process
            updatedProcess.appendSample(cpuPercentage)
            return (processId, updatedProcess)
        }
        let addedSamples = Dictionary(addedSamplesArray)
        let processAverageCPU = averageLatestSamples(addedSamples, numberOfSamples: 10)
        let filtered = filterAverages(processAverageCPU, threshold: cpuThreshold)
        let updatedProcesses = sendNotifications(addedSamples, overProcesses: filtered, notificationCenter: notificationCenter)
        let prunedProcesses = pruneProcesses(updatedProcesses, remainingSamples: remainingSamples)
        return prunedProcesses
    }

    private func getRunningApplications() -> [NSRunningApplication] {
        return NSWorkspace.sharedWorkspace().runningApplications
    }
    
    private func mergeApplications(processes: ProcessHash, applications: [NSRunningApplication]) -> ProcessHash {
        var outProcesses = processes;
        for application in applications {
            let maybeProcess = outProcesses[Int(application.processIdentifier)]
            if maybeProcess == nil {
                let process = Process(application: application)
                outProcesses[process.processId] = process
            }
        }
        // TODO: remove quit processes
        return outProcesses
    }
    
    private func printMachError(pid: pid_t, kerr: Int32) {
        let machString = String.fromCString(mach_error_string(kerr)) ?? "unknown error"
        print("Error pid: \(pid) - \(machString)")
    }
    
    // http://stackoverflow.com/questions/6788274/ios-mac-cpu-usage-for-thread
    // http://stackoverflow.com/questions/27556807/swift-pointer-problems-with-mach-task-basic-info
    private func getProcessCPUPercentage(processId: ProcessID) -> CPUPercentage {
        let pid: pid_t = Int32(processId)
        var port: task_t = 0  // UInt32
        var kerr: kern_return_t = KERN_FAILURE
        kerr = withUnsafeMutablePointer(&port) {
            task_for_pid(mach_task_self_, pid, $0)
        }
        
        if kerr != KERN_SUCCESS { printMachError(pid, kerr: kerr); return 0.0 } // TODO: Error handling
        
        var tinfo: task_basic_info = task_basic_info()
        var task_info_count: mach_msg_type_number_t = UInt32(TASK_INFO_MAX) // UInt32
        
        kerr = withUnsafeMutablePointer(&tinfo) {
            task_info(port, task_flavor_t(TASK_BASIC_INFO), task_info_t($0), &task_info_count)
        }
        
        if kerr != KERN_SUCCESS { printMachError(pid, kerr: kerr); return 0.0 } // TODO: Error handling

        let basic_info: task_basic_info = tinfo
        var thread_list: thread_array_t = UnsafeMutablePointer(nil)
        var thread_count: mach_msg_type_number_t = 0
        
        var thinfo: thread_basic_info = thread_basic_info()
        var thread_info_count: mach_msg_type_number_t = UInt32(THREAD_INFO_MAX)
        
        var basic_info_th: thread_basic_info
        var stat_thread: UInt32 = 0 // Mach threads
        
        // get threads in the task
        kerr = withUnsafeMutablePointers(&thread_list, &thread_count, {
            task_threads(port, $0, $1)
        })
        
        if kerr != KERN_SUCCESS { printMachError(pid, kerr: kerr); return 0.0 } // TODO: Error handling

        if (thread_count > 0) {
            stat_thread += thread_count
        }
        
        var tot_sec: Int = 0
        var tot_usec: Int = 0
        var tot_cpu: Int = 0
        
        for i in 0..<thread_count {
            let thread = thread_list[Int(i)]
            
            kerr = withUnsafeMutablePointer(&thinfo, {
                thread_info(thread, thread_flavor_t(THREAD_BASIC_INFO), thread_info_t($0), &thread_info_count)
            })
            
            if kerr != KERN_SUCCESS { printMachError(pid, kerr: kerr); return 0.0 } // TODO: Error handling
            
            basic_info_th = thinfo
            
            if (basic_info_th.flags & TH_FLAGS_IDLE) == 0 {
                tot_sec = Int(tot_sec + basic_info_th.user_time.seconds + basic_info_th.system_time.seconds)
                tot_usec = Int(tot_usec + basic_info_th.user_time.microseconds + basic_info_th.system_time.microseconds)
                tot_cpu = Int(tot_cpu + basic_info_th.cpu_usage)
            }
        }
        
        return CPUPercentage(tot_cpu)
    }
    
    private func averageLatestSamples(processes: ProcessHash, numberOfSamples: Int) -> [ProcessID: CPUPercentage] {
        let processLoadArray = processes
            .map { (processId: ProcessID, process: Process) -> (ProcessID, [CPUPercentage]) in
                let truncatedSamples = Array(process.samples.suffix(numberOfSamples))
                return (processId, truncatedSamples)
            }
            .map { (processID: ProcessID, samples: [CPUPercentage]) -> (ProcessID, CPUPercentage) in
                let total = samples.reduce(0, combine: +)
                let count = samples.count
                let average = total / Double(count)
                return (processID, average)
        }
        return Dictionary(processLoadArray)
    }
    
    private func filterAverages(averages: [ProcessID: CPUPercentage], threshold: CPUPercentage) -> [ProcessID: CPUPercentage] {
        let filteredAveragesArray = averages.filter({ (process: ProcessID, percentage: CPUPercentage) -> Bool in
            return percentage >= threshold
        })
        return Dictionary(filteredAveragesArray)
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
            // Configure local notification
            let notification = createUserNotification(
                getProcessName(processes, processId: processId),
                averagedTimePeriod: delay * numberOfAveragedSamples,
                cpuLoad: cpuLoad)
            pendingNotifications.append(notification)
            
            // Update process lastAlertAt
            var process = processes[processId]
            process?.lastAlertAt = now
            updatedProcesses[processId] = process
        }
        
        // Schedule notifications
        pendingNotifications.forEach { notificationCenter.scheduleNotification($0) }
        
        return updatedProcesses
    }
    
    private func createUserNotification(processName: String, averagedTimePeriod: Int, cpuLoad: CPUPercentage) -> NSUserNotification {
        let notificationString = "\(processName) has been using \(cpuLoad) CPU for \(averagedTimePeriod) seconds."
        let notification = NSUserNotification()
        notification.title = "Runaway Process Monitor"
        notification.subtitle = notificationString
        return notification
    }
    
    private func pruneProcesses(processes: ProcessHash, remainingSamples: Int) -> ProcessHash {
        let processesArray = processes.map { (processId: ProcessID, process: Process) -> (ProcessID, Process) in
            var outProcess = process
            outProcess.pruneSamples(remainingSamples)
            return (processId, outProcess)
        }
        let outProcesses = Dictionary(processesArray)
        return outProcesses
    }
}

struct Process {
    let processId: ProcessID // Int32
    let name: String
    var samples: [CPUPercentage] // TODO: Possibly created bounded FIFO queue
    var lastAlertAt: NSDate?
}

extension Process {
    init(application: NSRunningApplication) {
        let processId = Int(application.processIdentifier)
        self.processId = processId
        self.name = application.localizedName ?? "Process ID: \(processId)"
        self.samples = []
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
}

extension Dictionary {
    init(_ pairs: [Element]) {
        self.init()
        for (k, v) in pairs {
            self[k] = v
        }
    }
}