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
            self.setMetricsOrAddAttributes(to: trace, from: $0)
        }
        incrementMetricForParentEvent(of: event)
        
        traces.write { $0[event.id] = trace }
    }
    
    public func logEnd(_ event: BlackBox.EndEvent) {
        let id = event.startEvent.id
        
        guard let trace = traces.read ({ $0[id] })  else { return }
        
        event.userInfo.map {
            self.setMetricsOrAddAttributes(to: trace, from: $0)
        }
        
        trace.stop()
        
        traces.write { $0[id] = nil }
    }
}

extension FirebasePerformanceLogger {
    func setMetricsOrAddAttributes(to trace: Trace, from userInfo: BBUserInfo) {
        userInfo.forEach { key, value in
            if let metric = Metric((key, value)) {
                trace.setValue(metric.value, forMetric: metric.name)
            } else if let attribute = Attribute((key, value)) {
                // https://firebase.google.com/docs/perf-mon/custom-code-traces?platform=ios
                trace.setValue(attribute.value, forAttribute: attribute.name)
            }
        }
    }
}

// MARK: - Attributes
extension FirebasePerformanceLogger {
    struct Attribute {
        let name: String
        let value: String
        
        init(name: String, value: String) {
            self.name = name
            self.value = value
        }
        
        init?(_ pair: (key: String, value: Any)) {
            let stringValue: String
            switch pair.value {
            case Optional<Any>.none:
                return nil
            case let value as String:
                stringValue = value
            case let value as Error:
                stringValue = String(reflecting: value)
            default:
                stringValue = String(describing: pair.value)
            }
            
            self.init(name: pair.key, value: stringValue)
        }
    }
}

// MARK: - Metrics
extension FirebasePerformanceLogger {
    struct Metric {
        let name: String
        let value: Int64
        
        init(name: String, value: Int64) {
            self.name = name
            self.value = value
        }
        
        init?(_ pair: (key: String, value: Any)) {
            let intValue: Int64
            switch pair.value {
            case let value as Int:
                intValue = Int64(value)
            case let value as UInt:
                intValue = Int64(value)
            default:
                return nil
            }
            
            self.init(name: pair.key, value: intValue)
        }
    }
}
 
// MARK: Parent Event Metrics
extension FirebasePerformanceLogger {
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
