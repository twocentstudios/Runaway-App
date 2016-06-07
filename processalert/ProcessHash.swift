//
//  ProcessHash.swift
//  processalert
//
//  Created by Christopher Trott on 6/7/16.
//  Copyright © 2016 twocentstudios. All rights reserved.
//

typealias ProcessHash = [ProcessID: Process]

func getProcessName(processes: ProcessHash, processId: ProcessID) -> String {
    guard let process = processes[processId] else { fatalError("processId not contained in processes hash") }
    return process.name
}

// Returns the average load for processes where all latest samples are above the provided threshold.
func filterLatestSamples(processes: ProcessHash, numberOfSamples: Int, threshold: CPUPercentage) -> [ProcessID: CPUPercentage] {
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

func mergeRawProcesses(processes: ProcessHash, rawProcesses: RawProcesses) -> ProcessHash {
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

func pruneSamples(processes: ProcessHash, remainingSamples: Int) -> ProcessHash {
    let processesArray = processes.map { (processId: ProcessID, process: Process) -> (ProcessID, Process) in
        var outProcess = process
        outProcess.pruneSamples(remainingSamples)
        return (processId, outProcess)
    }
    let outProcesses = Dictionary(processesArray)
    return outProcesses
}