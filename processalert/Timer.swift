//
//  Timer.swift
//  processalert
//
//  Created by Christopher Trott on 6/7/16.
//  Copyright © 2016 twocentstudios. All rights reserved.
//

import Foundation

class RepeatingTimer {
    private var dispatchSource: dispatch_source_t? = nil
    
    init(interval: NSTimeInterval, leeway: NSTimeInterval, start: dispatch_time_t = DISPATCH_TIME_NOW, queue: dispatch_queue_t = dispatch_get_main_queue(), action: dispatch_block_t) {
        let timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue)
        guard timer != nil else { fatalError("Could not create timer.") }
        
        func nanoseconds(seconds: NSTimeInterval) -> UInt64 {
            enum Static { static let Multiplier = Double(NSEC_PER_SEC) }
            
            return UInt64(seconds * Static.Multiplier)
        }
        
        dispatch_source_set_event_handler(timer, action)
        dispatch_source_set_timer(timer, start, nanoseconds(interval), nanoseconds(leeway))
        
        dispatch_resume(timer)
        
        self.dispatchSource = timer
    }
    
    func cancel() {
        guard let source = self.dispatchSource else { return }
        dispatch_source_cancel(source)
        self.dispatchSource = nil
    }
}