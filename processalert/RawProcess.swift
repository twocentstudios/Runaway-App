//
//  RawProcess.swift
//  processalert
//
//  Created by Christopher Trott on 6/7/16.
//  Copyright © 2016 twocentstudios. All rights reserved.
//

import Foundation

struct RawProcess {
    let processId: ProcessID
    let name: String
    let sample: CPUPercentage
}

struct ProcessStatus {
    static let launchPath = "/bin/ps"
    static let arguments = ["-acwwwxo", "pid=,pcpu=,command="]
    
    static func parse(input: String) -> RawProcesses {
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
}