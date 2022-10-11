public protocol CachedAPICallDatasourceBundleProtocol {
    associatedtype APICallDatasource: PersistableStateDatasource
    typealias APICallState = APICallDatasource.DatasourceState
    typealias CachedDatasourceConcrete = CachedDatasource<APICallState.Value, APICallState.P, APICallState.E>
    typealias LoadImpulseEmitterConcrete = RecurringLoadImpulseEmitter<APICallState.P>
    typealias Persister = DiskStatePersister<APICallState.Value, APICallState.P, APICallState.E>
    
    var apiCallDatasource: APICallDatasource {get}
    var cachedDatasource: CachedDatasourceConcrete {get}
    var loadImpulseEmitter: LoadImpulseEmitterConcrete {get}
    var persister: Persister? {get}
}

public protocol PersistableStateDatasource: DatasourceProtocol where Value: Codable, P: Codable, E: CachedDatasourceError & Codable {}

/// Pure convenience bundle of:
/// - API call datasource whose last success state is retained when a reload
///     occurs (`.retainLastResult` applied).
/// - Disk state persister (for writing success states to disk)
/// - Cached datasource
///
public struct DefaultCachedAPICallDatasourceBundle<APICallDatasource_: PersistableStateDatasource>: CachedAPICallDatasourceBundleProtocol {
    public typealias APICallDatasource = APICallDatasource_
    public typealias APICallState = APICallDatasource.DatasourceState
    public typealias CachedDatasourceConcrete = CachedDatasource<APICallState.Value, APICallState.P, APICallState.E>
    public typealias LoadImpulseEmitterConcrete = RecurringLoadImpulseEmitter<APICallState.P>
    public typealias Persister = DiskStatePersister<APICallState.Value, APICallState.P, APICallState.E>
    
    public let apiCallDatasource: APICallDatasource
    public let cachedDatasource: CachedDatasourceConcrete
    public let loadImpulseEmitter: LoadImpulseEmitterConcrete
    public let persister: Persister? // optional because init can fail
    
    public init(primaryDatasourceGenerator: (LoadImpulseEmitterConcrete) -> APICallDatasource, initialLoadImpulse: LoadImpulse<APICallState.P>?, cacheKey: String) {
        
        let diskStatePersister = Persister(key: cacheKey)
        let loadImpulseEmitter = LoadImpulseEmitterConcrete.init(emitInitially: initialLoadImpulse)
        let primaryDatasource = primaryDatasourceGenerator(loadImpulseEmitter)
        let cacheLoadError = APICallDatasource.E.init(cacheLoadError: .default)
        let cacheDatasource = PlainCacheDatasource.init(persister: diskStatePersister.any, loadImpulseEmitter: loadImpulseEmitter.any, cacheLoadError: cacheLoadError)
        let lastResultRetainingPrimaryDatasource = primaryDatasource.retainLastResult
        
        self.cachedDatasource = CachedDatasourceConcrete(loadImpulseEmitter: loadImpulseEmitter.any, primaryDatasource: lastResultRetainingPrimaryDatasource.any, cacheDatasource: cacheDatasource.any, persister: diskStatePersister.any)
        self.apiCallDatasource = primaryDatasource
        self.persister = diskStatePersister
        self.loadImpulseEmitter = loadImpulseEmitter
    }
}
