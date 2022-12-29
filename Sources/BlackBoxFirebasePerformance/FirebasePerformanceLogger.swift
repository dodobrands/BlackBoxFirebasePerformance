//
//  FirebasePerformanceLogger.swift
//  DodoPizza
//
//  Created by Алексей Берёзка on 13.10.2021.
//  Copyright © 2021 Dodo Pizza. All rights reserved.
//

import Foundation
import BlackBox
import FirebasePerformance

class FirebasePerformanceLogger: BBLoggerProtocol {
    private let levels: [BBLogLevel]
    
    private var traces = [UUID: Trace]()
    
    public init(levels: [BBLogLevel]) {
        self.levels = levels
    }
    
    func log(_ event: BlackBox.ErrorEvent) {
        incrementMetricForParentEvent(of: event)
    }
    
    func log(_ event: BlackBox.GenericEvent) {
        incrementMetricForParentEvent(of: event)
    }
    
    func logStart(_ event: BlackBox.StartEvent) {
        let traceName = name(of: event, forMetric: false)
        guard let trace = Performance.startTrace(name: traceName) else { return }
        
        event.userInfo.map { self.addAttributes(to: trace, from: $0) }
        incrementMetricForParentEvent(of: event)
        
        traces[event.id] = trace
    }
    
    func logEnd(_ event: BlackBox.EndEvent) {
        let id = event.startEvent.id
        
        guard let trace = self.traces[id] else { return }
        
        event.userInfo.map { self.addAttributes(to: trace, from: $0) }
        incrementMetricForParentEvent(of: event)
        
        trace.stop()
        
        traces[id] = nil
    }
    
    func incrementMetric(trace: Trace, metricName: String) {
        trace.incrementMetric(metricName, by: 1)
    }
}

extension FirebasePerformanceLogger {
    // https://firebase.google.com/docs/perf-mon/custom-code-traces?platform=ios
    private func addAttributes(to trace: Trace, from userInfo: BBUserInfo) {
        userInfo.forEach { attributeName, value in
            guard let stringifiedValue = stringifiedValue(from: value) else { return }
            
            trace.setValue(stringifiedValue, forAttribute: attributeName)
        }
    }
    
    private func stringifiedValue(from value: Any) -> String? {
        guard !isNil(value) else { return nil }
        
        switch value {
        case let value as String:
            return value
        case let value as Error:
            return String(reflecting: value)
        default:
            return String(describing: value)
        }
    }
    
    private func incrementMetricForParentEvent(of event: BlackBox.GenericEvent) {
        guard let parentEvent = event.parentEvent else { return }
        guard let trace = traces[parentEvent.id] else { return }
        
        let metricName = name(of: event, forMetric: true)
        
        incrementMetric(trace: trace, metricName: metricName)
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
            // Load menu
            name = message
        } else {
            // [Menu.ImportService] Load menu
            let source = [event.source.module, event.source.filename].joined(separator: ".")
            name = "[\(source)] \(message)"
        }
        
        return name
    }
}

protocol OptionalProtocol {
    var isNil: Bool { get }
}

extension Optional: OptionalProtocol {
    public var isNil: Bool { return self == nil }
}

func isNil(_ input: Any) -> Bool {
    return (input as? OptionalProtocol)?.isNil ?? false
}
