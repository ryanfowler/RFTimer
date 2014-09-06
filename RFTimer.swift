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
    var tagName: String
    var timer = NSTimer()
    var intervals = 0
    var inTimer = false
    var delegate: RFTimerDelegate?
    let notifCenter = NSNotificationCenter.defaultCenter()
    
    /**
    Start the timer
    */
    public func start() {
        
        if !inTimer {
            startTime = NSDate()
            delegate?.timerStatusUpdated(self, isOn: true)
            timer = NSTimer.scheduledTimerWithTimeInterval(0.1, target: self, selector: "timerFireMethod", userInfo: nil, repeats: true)
            if let err = SD.executeChange("INSERT INTO RFTimerTemp (StartingTime, Tag, Singleton) VALUES (?, ?, 0)", withArgs: [startTime!, tagName]) {
                println("Error inserting item to RFTimerTemp")
            }
            intervals = 0
            inTimer = true
            println("Timer started")
        }
        
    }
    
    /**
    Stop the timer and save it in the database
    */
    public func stopAndSave() {
        
        if inTimer {
            timer.invalidate()
            delegate?.timerStatusUpdated(self, isOn: false)
            
            //insert the new timer event
            if let err = SD.executeChange("INSERT INTO RFTimer (StartingTime, EndingTime, Duration, Tag) VALUES (\(SD.escapeValue(startTime!)), \(SD.escapeValue(NSDate())), \(SD.escapeValue(Int(NSDate().timeIntervalSinceDate(startTime!)))), \(SD.escapeValue(tagName)))") {
                println("Error inserting row into RFTimer")
            }
            
            //delete the temp timer
            if let err = SD.executeChange("DELETE FROM RFTimerTemp") {
                println("Error deleting row from RFTimerTemp")
            }
            
            inTimer = false
            println("Timer stopped")
        }
        
    }
    
    
    init(tag: String) {
        
        //create RFTimerTemp table in the database if it does not already exist
        if let err = SD.executeChange("CREATE TABLE IF NOT EXISTS RFTimerTemp (ID INTEGER PRIMARY KEY AUTOINCREMENT, StartingTime DATE, Tag TEXT, Singleton INTEGER UNIQUE)") {
            println("Error attempting to create RFTimerTemp table in the RFTimer database")
        }
        
        //create RFTimer table in the database if it does not already exist
        if let err = SD.executeChange("CREATE TABLE IF NOT EXISTS RFTimer (ID INTEGER PRIMARY KEY AUTOINCREMENT, StartingTime DATE, EndingTime DATE, Duration INTEGER, Tag TEXT)") {
            println("Error attempting to create the RTTimer table in the database")
        }
        
        //create index on Tag column if it does not already exist
        if let err = SD.executeChange("CREATE INDEX IF NOT EXISTS TagIndex ON RFTimer (Tag)") {
            println("Error attempting to create TagIndex on the RFTimer table")
        }
        
        //add the tag
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
        if intervals % 20 == 0 {
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
                    if let tag = result[0]["Tag"]?.asString() {
                        intervals = Int(NSDate().timeIntervalSinceDate(start)) * 10
                        inTimer = true
                        startTime = start
                        tagName = tag
                        delegate?.timerFired(self, seconds: intervals/10 % 60, minutes: intervals/600 % 60, hours: intervals/36000)
                        delegate?.timerStatusUpdated(self, isOn: true)
                        timer = NSTimer.scheduledTimerWithTimeInterval(0.1, target: self, selector: "timerFireMethod", userInfo: nil, repeats: true)
                    }
                }
            }
        }
        
    }
    
    @objc private func sleepTimer() {
        
        if inTimer {
            println("Timer sent to sleep")
            delegate?.timerStatusUpdated(self, isOn: true)
            timer.invalidate()
        }
        
    }
    
}

public protocol RFTimerDelegate {
    
    /**
    The timer has fired
    
    Anything that needs to be done when there is a change of time, such as update the UI, should be done in this function.
    This functions gets called roughly 10 times a second.
    */
    func timerFired(timer: RFTimer, seconds: Int, minutes: Int, hours: Int)
    
    /**
    The timer status has been updated
    
    This function gets called when the timer has been turned on, woken from sleep, turned off, or sent to sleep.
    */
    func timerStatusUpdated(timer: RFTimer, isOn: Bool)
    
}

extension SwiftData {
    
    /**
    Get all existing tags
    
    :returns:  An array of strings with all existing tags, or nil if there was an error
    */
    public static func getAllTags() -> [String]? {
        var (results, err) = SD.existingTables()
        if err != nil {
            println("Error finding tables")
        } else {
            var tables = [String]()
            for result in results {
                if result != "sqlite_sequence" && result != "RFTimerTemp" {
                    tables.append(result)
                }
            }
            return tables
        }
        return nil
    }

}
