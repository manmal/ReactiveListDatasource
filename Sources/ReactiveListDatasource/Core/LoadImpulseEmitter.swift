import Foundation
import ReactiveSwift

public protocol LoadImpulseEmitterProtocol {
    associatedtype P: Parameters
    
    var loadImpulses: SignalProducer<LoadImpulse<P>, Never> {get}
    func emit(_ loadImpulse: LoadImpulse<P>)
}

public extension LoadImpulseEmitterProtocol {
    var any: AnyLoadImpulseEmitter<P> {
        return AnyLoadImpulseEmitter(self)
    }
}

public struct AnyLoadImpulseEmitter<P_: Parameters>: LoadImpulseEmitterProtocol {
    public typealias P = P_
    
    public let loadImpulses: SignalProducer<LoadImpulse<P_>, Never>
    private let _emit: (LoadImpulse<P>) -> ()
    
    init<E: LoadImpulseEmitterProtocol>(_ emitter: E) where E.P == P {
        self.loadImpulses = emitter.loadImpulses
        self._emit = emitter.emit
    }
    
    public func emit(_ loadImpulse: LoadImpulse<P_>) {
        _emit(loadImpulse)
    }
}


public struct DefaultLoadImpulseEmitter<P_: Parameters>: LoadImpulseEmitterProtocol {
    public typealias P = P_
    public typealias LI = LoadImpulse<P>
    private typealias Pipe = (output: Signal<LI, Never>, input: Signal<LI, Never>.Observer)

    public let loadImpulses: SignalProducer<LI, Never>
    private let pipe: Pipe

    public init(emitInitially initialImpulse: LoadImpulse<P>?) {
        
        func loadImpulsesProducer(pipe: Pipe, initialImpulse: LI?) -> SignalProducer<LI, Never> {
            let impulses = SignalProducer(pipe.output)
            if let initialImpulse = initialImpulse {
                return SignalProducer(value: initialImpulse).concat(impulses)
            } else {
                return impulses
            }
        }
        
        let pipe = Signal<LoadImpulse<P>, Never>.pipe()
        self.loadImpulses = loadImpulsesProducer(pipe: pipe, initialImpulse: initialImpulse)
        self.pipe = pipe
    }

    public func emit(_ loadImpulse: LoadImpulse<P>) {
        pipe.input.send(value: loadImpulse)
    }

}

public struct RecurringLoadImpulseEmitter<P_: Parameters>: LoadImpulseEmitterProtocol {
    public typealias P = P_
    public typealias LI = LoadImpulse<P>
    private typealias Pipe = (output: Signal<LI, Never>, input: Signal<LI, Never>.Observer)
    
    private let innerEmitter: DefaultLoadImpulseEmitter<P>
    public let loadImpulses: SignalProducer<LI, Never>
    public let timerMode: MutableProperty<TimerMode> // change at any time to adapt
    
    public init(emitInitially initialImpulse: LoadImpulse<P>?, timerMode: TimerMode = .none) {
        
        let timerModeProperty = MutableProperty(timerMode)
        self.timerMode = timerModeProperty
        self.innerEmitter = DefaultLoadImpulseEmitter<P>.init(emitInitially: initialImpulse)
        
        self.loadImpulses = innerEmitter.loadImpulses
            .combineLatest(with: timerModeProperty.producer)
            .flatMap(.latest, { (loadImpulse, timerMode) -> SignalProducer<LoadImpulse<P>, Never> in
                let current = SignalProducer<LoadImpulse<P>, Never>(value: loadImpulse)
                
                switch timerMode {
                case .none:
                    return current
                case let .timeInterval(timeInterval):
                    let subsequent = SignalProducer.timer(interval: timeInterval, on: QueueScheduler.main).map({ _ in loadImpulse })
                    return current.concat(subsequent)
                }
            })
    }
    
    public func emit(_ loadImpulse: LoadImpulse<P>) {
        innerEmitter.emit(loadImpulse)
    }
    
    public enum TimerMode {
        case none
        case timeInterval(DispatchTimeInterval)
    }
    
}
