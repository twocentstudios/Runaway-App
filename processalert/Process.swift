//
//  Process.swift
//  processalert
//
//  Created by Christopher Trott on 6/7/16.
//  Copyright © 2016 twocentstudios. All rights reserved.
//

import Foundation

typealias CPUPercentage = Double
typealias ProcessID = Int

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