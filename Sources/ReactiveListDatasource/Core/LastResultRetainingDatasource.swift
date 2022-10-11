import Foundation
import ReactiveSwift

/// Repeats a datasource's last value and/or error, mixed into
/// the latest returned state. E.g. if the original datasource
/// has sent a state with a value and provisioningState == .result,
/// then value is attached to subsequent states as `fallbackValue`
/// until a new state with a value and provisioningState == .result
/// is sent. Same with errors.
///
/// Discussion: A list view is not only interested in the very last
/// state of a datasource, but also in previous ones. E.g. on
/// pull-to-refresh, the original datasource might decide to emit
/// a loading state without a value - which would result in the
/// list view showing an empty view, or a loading view until the
/// next state with a value is sent (same with errors).
/// This struct helps with this by caching the last value and/or
/// error,.
public struct LastResultRetainingDatasource<Value_: Any, P_: Parameters, E_: DatasourceError>: DatasourceProtocol {
    public typealias Value = Value_
    public typealias P = P_
    public typealias E = E_
    
    public typealias SubDatasource = AnyDatasource<Value, P, E>
    public typealias LoadImpulseEmitterConcrete = AnyLoadImpulseEmitter<P>
    
    public let loadsSynchronously = true
    
    public let state: SignalProducer<DatasourceState, Never>
    
    public init(innerDatasource: SubDatasource) {
        self.state = LastResultRetainingDatasource.stateProducer(innerDatasource: innerDatasource)
    }
    
    private static func stateProducer(innerDatasource: SubDatasource)
        -> SignalProducer<DatasourceState, Never> {
            let initialState = SignalProducer(value: DatasourceState.notReady)
            let lazyStates: SignalProducer<DatasourceState, Never> = {
                if innerDatasource.loadsSynchronously {
                    return innerDatasource.state.replayLazily(upTo: 1).skipRepeats()
                } else {
                    return initialState.concat(innerDatasource.state.replayLazily(upTo: 1)).skipRepeats()
                }
            }()
            let values = initialState
                .concat(lazyStates.filter({
                    switch $0.provisioningState {
                    case .result: return $0.value != nil
                    case .loading, .notReady: return false
                    }
                }))
                .skipRepeats()
            let errors = initialState
                .concat(lazyStates.filter({
                    switch $0.provisioningState {
                    case .result: return $0.error != nil
                    case .loading, .notReady: return false
                    }
                }))
                .skipRepeats()
            
            return SignalProducer.combineLatest(lazyStates, values, errors)
                .map { currentState, fallbackValueState, fallbackErrorState -> DatasourceState in
                    switch currentState.provisioningState {
                    case .notReady:
                        return DatasourceState.notReady
                    case .loading:
                        guard let loadImpulse = currentState.loadImpulse else { return .notReady }
                        
                        let value = self.value(currentState: currentState, fallbackValueState: fallbackValueState, loadImpulse: loadImpulse)
                        let error = self.error(currentState: currentState, fallbackErrorState: fallbackErrorState, loadImpulse: loadImpulse)
                        return DatasourceState.loading(loadImpulse: loadImpulse, fallbackValue: value, fallbackError: error)
                    case .result:
                        guard let loadImpulse = currentState.loadImpulse else { return .notReady }
                        
                        if let error = currentState.cacheCompatibleError(for: loadImpulse) {
                            let value = self.value(currentState: currentState, fallbackValueState: fallbackValueState, loadImpulse: loadImpulse)
                            return DatasourceState.error(error: error, loadImpulse: loadImpulse, fallbackValue: value)
                        } else if let valueBox = currentState.cacheCompatibleValue(for: loadImpulse) {
                            // We have a definitive success result, with no error, so we erase all previous errors
                            return DatasourceState.value(value: valueBox.value, loadImpulse: loadImpulse, fallbackError: nil)
                        } else {
                            // Latest state might not match current parameters - return .notReady
                            // so all cached data is purged. This can happen if e.g. an authenticated API
                            // request has been made, but the user has logged out in the meantime. The result
                            // must be discarded or the next logged in user might see the previous user's data.
                            return DatasourceState.notReady
                        }
                    }
            }
            
    }
    
    /// Returns either the current state's value, or the fallbackValueState's.
    /// If neither is set, returns nil.
    private static func value(currentState: DatasourceState, fallbackValueState: DatasourceState, loadImpulse: LoadImpulse<P>) -> Value? {
        if let currentStateValueBox = currentState.cacheCompatibleValue(for: loadImpulse) {
            return currentStateValueBox.value
        } else if let fallbackValueStateValueBox = fallbackValueState.cacheCompatibleValue(for: loadImpulse) {
            return fallbackValueStateValueBox.value
        } else {
            return nil
        }
    }
    
    /// Returns either the current state's error, or the fallbackErrorState's.
    /// If neither is set, returns nil.x
    private static func error(currentState: DatasourceState, fallbackErrorState: DatasourceState, loadImpulse: LoadImpulse<P>) -> E? {
        if let currentStateError = currentState.cacheCompatibleError(for: loadImpulse) {
            return currentStateError
        } else if let fallbackErrorStateError = fallbackErrorState.cacheCompatibleError(for: loadImpulse) {
            return fallbackErrorStateError
        } else {
            return nil
        }
    }
    
}

public extension DatasourceProtocol {
    
    typealias LastResultRetaining = LastResultRetainingDatasource<Value, P, E>
    
    var retainLastResult: LastResultRetaining {
        return LastResultRetaining(innerDatasource: self.any)
    }
}
