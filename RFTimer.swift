//
// RFTimer.swift
//
// Copyright (c) 2014 Ryan Fowler
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.


import Foundation
import UIKit


public class RFTimer {
    
    //declare RFTimer properties
    var startTime: NSDate?
    let tagName: String
    var timer = NSTimer()
    var intervals = 0
    var inTimer = false
    var delegate: RFTimerDelegate?
    let notifCenter = NSNotificationCenter.defaultCenter()
    
    
    public func start() {
        
        if !inTimer {
            startTime = NSDate()
            timer = NSTimer.scheduledTimerWithTimeInterval(0.1, target: self, selector: "timerFireMethod", userInfo: nil, repeats: true)
            if let err = SD.executeChange("INSERT INTO RFTimerTemp (StartingTime, Tag) VALUES (?, ?)", withArgs: [startTime!, tagName]) {
                println("Error inserting item to RFTimerTemp")
            }
            intervals = 0
            inTimer = true
        }
        
    }
    
    
    public func stop() {
        
        if inTimer {
            timer.invalidate()
            if let err = SD.executeChange("DELETE FROM RFTimerTemp") {
                println("Error deleting row from RFTimerTemp")
            }
            if let err = SD.executeChange("INSERT INTO RFTimerEvents (StartingTime, EndingTime, Duration, Tag) VALUES (?, ?, ? ,?)", withArgs: [startTime!, NSDate(), Int(NSDate().timeIntervalSinceDate(startTime!)), tagName]) {
                println("Error inserting row into RFTimerEvents")
            }
            inTimer = false
        }
        
        
    }
    
    
    init(tag: String) {
        
        //create RFTable tables in the database if they do not already exist
        if let err = SD.executeChange("CREATE TABLE IF NOT EXISTS RFTimerTemp (ID INTEGER PRIMARY KEY AUTOINCREMENT, StartingTime DATE, Tag TEXT)") {
            println("Error attempting to create RFTimerTemp table in the RFTimer database")
        }
        if let err = SD.executeChange("CREATE TABLE IF NOT EXISTS RFTimerEvents (ID INTEGER PRIMARY KEY AUTOINCREMENT, StartingTime DATE, EndingTime DATE, Duration INTEGER, Tag TEXT)") {
            println("Error attempting to create RFTimerEvents table in the RFTimer database")
        }
        
        //create index on Tag column if it does not already exist
        if let err = SD.executeChange("CREATE INDEX IF NOT EXISTS TagIndex ON RFTimerEvents (Tag)") {
            println("Error attempting to create TagIndex on RFTimerEvents table")
        }
        
        //assign tag name and timerFiredClosure
        tagName = tag
        
        //add self as an observer
        notifCenter.addObserver(self, selector: "wakeTimer", name: UIApplicationDidBecomeActiveNotification, object: nil)
        notifCenter.addObserver(self, selector: "sleepTimer", name: UIApplicationDidEnterBackgroundNotification, object: nil)
        
    }
    
    deinit {
        notifCenter.removeObserver(self)
    }
    
    @objc private func timerFireMethod() {
        
        ++intervals
        if intervals % 50 == 0 {
            intervals = Int(NSDate().timeIntervalSinceDate(startTime!)) * 10
        }
        
        delegate?.timerFired(self, seconds: intervals/10 % 60, minutes: intervals/600 % 60, hours: intervals/36000)
        
    }
    
    @objc private func wakeTimer() {
        
        let (result, err) = SD.executeQuery("SELECT * FROM RFTimerTemp")
        if err != nil {
            println("Query of RFTimerTemp failed")
        } else {
            if result.count > 0 {
                println("Timer awoken from sleep")
                if let start = result[0]["StartingTime"]?.asDate() {
                    intervals = Int(NSDate().timeIntervalSinceDate(start)) * 10
                    inTimer = true
                    startTime = start
                    delegate?.timerFired(self, seconds: intervals/10 % 60, minutes: intervals/600 % 60, hours: intervals/36000)
                    timer = NSTimer.scheduledTimerWithTimeInterval(0.1, target: self, selector: "timerFireMethod", userInfo: nil, repeats: true)
                }
            }
        }
        
    }
    
    @objc private func sleepTimer() {
        
        if inTimer {
            println("Timer sent to sleep")
            timer.invalidate()
        }
        
    }
    
}

public protocol RFTimerDelegate {
    
    func timerFired(timer: RFTimer, seconds: Int, minutes: Int, hours: Int)
    
}