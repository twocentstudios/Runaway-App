//
//  Shell.swift
//  processalert
//
//  Created by Christopher Trott on 6/7/16.
//  Copyright © 2016 twocentstudios. All rights reserved.
//

import Foundation

func shell(launchPath: String, arguments: [String]) -> String {
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