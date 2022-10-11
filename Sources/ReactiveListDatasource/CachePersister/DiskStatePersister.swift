import Foundation
import Cache

public struct DiskStatePersister<Value_: Codable, P_: Parameters & Codable, E_: DatasourceError & Codable>: StatePersister {
    public typealias Value = Value_
    public typealias P = P_
    public typealias E = E_
    
    public typealias StatePersistenceKey = String
    
    private let key: StatePersistenceKey
    private let storage: Storage<StatePersistenceKey, PersistedState>?
    
    public init(key: StatePersistenceKey, storage: Storage<StatePersistenceKey, PersistedState>?) {
        self.key = key
        self.storage = storage
    }
    
    public init(key: StatePersistenceKey, diskConfig: DiskConfig? = nil, memoryConfig: MemoryConfig? = nil) {
        
        var fallbackDiskConfig: DiskConfig {
            return DiskConfig(name: key)
        }
        
        var fallbackMemoryConfig: MemoryConfig {
            return MemoryConfig(expiry: .never, countLimit: 10, totalCostLimit: 10)
        }
        
        var transformer: Transformer<PersistedState> {
            return Transformer.init(toData: { state -> Data in
                return try JSONEncoder().encode(state)
            }, fromData: { data -> PersistedState in
                return try JSONDecoder().decode(State.self, from: data)
            })
        }
        
        let storage = try? Storage<StatePersistenceKey, State>.init(diskConfig: diskConfig ?? fallbackDiskConfig, memoryConfig: memoryConfig ?? fallbackMemoryConfig, transformer: transformer)
        
        self.init(key: key, storage: storage)
    }
    
    public func persist(_ state: PersistedState) {
        try? storage?.setObject(state, forKey: "latestValue")
    }
    
    public func load(_ parameters: P) -> PersistedState? {
        guard let storage = self.storage else {
            return nil
        }
        
        do {
            let state = try storage.object(forKey: "latestValue")
            if (state.loadImpulse?.parameters.isCacheCompatible(parameters) ?? false) {
                return state
            } else {
                return nil
            }
        } catch {
            return nil
        }
    }
    
    public func purge() {
        try? storage?.removeAll()
    }
    
}
