import Foundation
import ReactiveSwift

/// Maintains state coming from multiple sources (primary and cache).
/// It is able to support pagination, live feeds, etc in the primary datasource (yet to be implemented).
/// State coming from the primary datasource is treated as preferential over state from
/// the cache datasource. You can think of the cache datasource as cache.
public struct CachedDatasource<Value_, P_: Parameters, E_: DatasourceError>: DatasourceProtocol {
    public typealias Value = Value_
    public typealias P = P_
    public typealias E = E_
    
    public typealias SubDatasource = AnyDatasource<Value, P, E>
    public typealias LoadImpulseEmitterConcrete = AnyLoadImpulseEmitter<P>
    public typealias StatePersisterConcrete = AnyStatePersister<Value, P, E>
    
    private let loadImpulseEmitter: LoadImpulseEmitterConcrete
    public let loadsSynchronously = true
    
    private let stateProperty: Property<DatasourceState>
    public var state: SignalProducer<DatasourceState, Never> {
        return stateProperty.producer
    }
    
    public init(loadImpulseEmitter: LoadImpulseEmitterConcrete,
                primaryDatasource: SubDatasource,
                cacheDatasource: SubDatasource,
                persister: StatePersisterConcrete?) {
        self.loadImpulseEmitter = loadImpulseEmitter
        let stateProducer = CachedDatasource.cachedStatesProducer(loadImpulseEmitter: loadImpulseEmitter, primaryDatasource: primaryDatasource, cacheDatasource: cacheDatasource, persister: persister)
        self.stateProperty = Property(initial: State.notReady, then: stateProducer)
    }
    
    @discardableResult
    public func load(_ loadImpulse: LoadImpulse<P>) -> LoadingStarted {
        
        guard !shouldSkipLoad(for: loadImpulse) else {
            return false
        }
        
        loadImpulseEmitter.emit(loadImpulse)
        return true
    }
    
    /// Defers loading until returned SignalProducer is subscribed to.
    /// Once loading is done, returned SignalProducer sends the new
    /// state and completes.
    public func loadDeferred(_ loadImpulse: LoadImpulse<P>) -> SignalProducer<DatasourceState, Never> {
        return SignalProducer.init({ (observer, lifetime) in
            self.stateProperty.producer
                .skip(first: 1) // skip first (= current) value
                .filter({ state -> Bool in // only allow end-states (error, success)
                    switch state.provisioningState {
                    case .result:
                        return true
                    case .notReady, .loading:
                        return false
                    }
                })
                .startWithValues({ cachedState in
                    observer.send(value: cachedState)
                    observer.sendCompleted()
                })
            self.load(loadImpulse)
        })
    }
    
    /// Should be subscribed to BEFORE a load is performed.
    public var loadingEnded: SignalProducer<Void, Never> {
        return stateProperty.producer
            .skip(first: 1) // skip first (= current) value
            .filter({ state -> Bool in // only allow end-states (error, success)
                switch state.provisioningState {
                case .result:
                    return true
                case .notReady, .loading:
                    return false
                }
            })
            .map({ _ in () })
            .observe(on: UIScheduler())
    }
    
    private func shouldSkipLoad(for loadImpulse: LoadImpulse<P>) -> Bool {
        return loadImpulse.skipIfResultAvailable && stateProperty.value.hasLoadedSuccessfully
    }
    
    private static func cachedStatesProducer(loadImpulseEmitter: LoadImpulseEmitterConcrete,
                                             primaryDatasource: SubDatasource,
                                             cacheDatasource: SubDatasource,
                                             persister: StatePersisterConcrete? = nil)
        -> SignalProducer<DatasourceState, Never> {
            
            let primaryStates = primaryDatasource.stateWithSynchronousInitial
            let cachedStates = cacheDatasource.stateWithSynchronousInitial
            let loadImpulse = loadImpulseEmitter.loadImpulses.skipRepeats()
            
            return SignalProducer
                // All these signals will send .notReady or a
                // cached state immediately on subscription:
                .combineLatest(cachedStates, primaryStates)
                .combineLatest(with: loadImpulse)
                .map({ arg -> DatasourceState in
                    
                    let ((cache, primary), loadImpulse) = arg
                    
                    switch primary.provisioningState {
                    case .notReady, .loading:
                        
                        if let primaryValueBox = primary.cacheCompatibleValue(for: loadImpulse) {
                            return State.loading(loadImpulse: loadImpulse, fallbackValue: primaryValueBox.value, fallbackError: primary.error)
                        } else if let cacheValueBox = cache.cacheCompatibleValue(for: loadImpulse) {
                            return State.loading(loadImpulse: loadImpulse, fallbackValue: cacheValueBox.value, fallbackError: cache.error)
                        } else {
                            // Neither remote success nor cachely cached value
                            switch primary.provisioningState {
                            case .notReady, .result: return State.notReady
                                // Add primary as fallback so any errors are added
                            case .loading: return State.loading(loadImpulse: loadImpulse, fallbackValue: nil, fallbackError: primary.error)
                            }
                        }
                    case .result:
                        if primary.hasLoadedSuccessfully {
                            persister?.persist(primary)
                        }
                        
                        if let primaryValueBox = primary.cacheCompatibleValue(for: loadImpulse) {
                            if let error = primary.error {
                                return State.error(error: error, loadImpulse: loadImpulse, fallbackValue: primaryValueBox.value)
                            } else {
                                return State.value(value: primaryValueBox.value, loadImpulse: loadImpulse, fallbackError: nil)
                            }
                        } else if let error = primary.error {
                            if let cachedValueBox = cache.cacheCompatibleValue(for: loadImpulse) {
                                return State.error(error: error, loadImpulse: loadImpulse, fallbackValue: cachedValueBox.value)
                            } else {
                                return State.error(error: error, loadImpulse: loadImpulse, fallbackValue: nil)
                            }
                        } else {
                            // Remote state might not match current parameters - return .notReady
                            // so all cached data is purged. This can happen if e.g. an authenticated API
                            // request has been made, but the user has logged out in the meantime. The result
                            // must be discarded or the next logged in user might see the previous user's data.
                            return State.notReady
                        }
                    }
                })
    }
    
}

public typealias LoadingStarted = Bool

//public extension DatasourceProtocol {
//
//    public func cached(with cacheDatasource: AnyDatasource<State>, loadImpulseEmitter: AnyLoadImpulseEmitter<State.P, State.LIT>, persister: AnyStatePersister<State>?) -> CachedDatasource<State> {
//        return CachedDatasource<State>.init(loadImpulseEmitter: loadImpulseEmitter, primaryDatasource: self.any, cacheDatasource: cacheDatasource, persister: persister)
//    }
//}
