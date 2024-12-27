//
//  FirebasePerformanceLogger.swift
//  DodoPizza
//
//  Created by Алексей Берёзка on 13.10.2021.
//  Copyright © 2021 Dodo Pizza. All rights reserved.
//

import Foundation
import BlackBox
import DBThreadSafe
import FirebasePerformance

public class FirebasePerformanceLogger: BBLoggerProtocol {
    private let levels: [BBLogLevel]
    
    private var traces = DBThreadSafeContainer([UUID: Trace]())
    
    public init(levels: [BBLogLevel]) {
        self.levels = levels
    }
    
    public func log(_ event: BlackBox.ErrorEvent) {
        incrementMetricForParentEvent(of: event)
    }
    
    public func log(_ event: BlackBox.GenericEvent) {
        incrementMetricForParentEvent(of: event)
    }
    
    public func logStart(_ event: BlackBox.StartEvent) {
        let traceName = name(of: event, forMetric: false)
        guard let trace = Performance.startTrace(name: traceName) else { return }
        
        event.userInfo.map {
            self.addAttributes(to: trace, from: $0)
            self.setMetrics(to: trace, from: $0)
        }
        incrementMetricForParentEvent(of: event)
        
        traces.write { $0[event.id] = trace }
    }
    
    public func logEnd(_ event: BlackBox.EndEvent) {
        let id = event.startEvent.id
        
        guard let trace = traces.read ({ $0[id] })  else { return }
        
        event.userInfo.map {
            self.addAttributes(to: trace, from: $0)
            self.setMetrics(to: trace, from: $0)
        }
        
        trace.stop()
        
        traces.write { $0[id] = nil }
    }
}

// MARK: Attributes
extension FirebasePerformanceLogger {
    // https://firebase.google.com/docs/perf-mon/custom-code-traces?platform=ios
    private func addAttributes(to trace: Trace, from userInfo: BBUserInfo) {
        userInfo.forEach { attributeName, value in
            guard let stringifiedValue = stringifiedValue(from: value) else { return }
            
            trace.setValue(stringifiedValue, forAttribute: attributeName)
        }
    }
    
    private func stringifiedValue(from value: Any) -> String? {
        switch value {
        case Optional<Any>.none:
            return nil
        case let value as String:
            return value
        case let value as Error:
            return String(reflecting: value)
        case _ as Int:
            return nil
        default:
            return String(describing: value)
        }
    }
}

// MARK: Metrics
extension FirebasePerformanceLogger {
    struct Metric {
        let name: String
        let value: Int64
    }
    
    private func setMetrics(to trace: Trace, from userInfo: BBUserInfo) {
        let mterics = metrics(from: userInfo)
        mterics.forEach { trace.setValue($0.value, forMetric: $0.name) }
    }
    
    private func metrics(from userInfo: BBUserInfo) -> [Metric] {
        userInfo.compactMap { key, value in
            guard let value = int64Value(from: value) else { return nil }
            return Metric(name: key, value: value)
        }
    }
    
    private func int64Value(from value: Any) -> Int64? {
        if let value = value as? Int {
            return Int64(value)
        } else if let value = value as? UInt {
            return Int64(value)
        } else {
            return nil
        }
    }
    
    private func incrementMetricForParentEvent(of event: BlackBox.GenericEvent) {
        guard let parentEvent = event.parentEvent else { return }
        guard let trace = traces.read({ $0[parentEvent.id] }) else { return }
        
        let metricName = name(of: event, forMetric: true)
        
        trace.incrementMetric(metricName, by: 1)
    }
    
    private func name(of event: BlackBox.GenericEvent, forMetric: Bool) -> String {
        let message: String
        switch event {
        case let start as BlackBox.StartEvent:
            message = forMetric ? start.message : start.rawMessage.description
        case let start as BlackBox.EndEvent:
            message = forMetric ? start.message : start.rawMessage.description
        default:
            message = event.message
        }
        
        let name: String
        if forMetric {
            // Message
            name = message
        } else {
            // [TargetName.ClassName] Message
            let source = [event.source.module, event.source.filename].joined(separator: ".")
            name = "[\(source)] \(message)"
        }
        
        return name
    }
}
