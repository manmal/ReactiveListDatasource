import Foundation
import UIKit
import ReactiveSwift

public struct DefaultSingleSectionListViewDatasourceCore<Datasource: DatasourceProtocol, ItemViewProducer: ListItemViewProducer> {
    
    public typealias Item = ItemViewProducer.Item
    public typealias Items = SingleSectionListItems<Item>
    public typealias ItemToView = (Item.ViewType) -> ItemViewProducer
    public typealias ValueToItems = (Datasource.DatasourceState.Value) -> [Item]?
    public typealias ItemSelected = (Item) -> ()
    public typealias StateToItems =
        (_ state: Datasource.DatasourceState,
        _ valueToItems: @escaping ValueToItems,
        _ loadingItem: (() -> Item)?,
        _ errorItem: ((Datasource.E) -> Item)?,
        _ noResultsItem: (() -> Item)?) -> SingleSectionListItems<Item>
    
    public var stateToItems: StateToItems // Might be set by
    public var valueToItems: ValueToItems?
    public var itemSelected: ItemSelected?
    public var itemToViewMapping: [Item.ViewType: ItemViewProducer] = [:]
    
    public var loadingItem: (() -> Item)?
    public var errorItem: ((Datasource.E) -> Item)?
    public var noResultsItem: (() -> Item)?
    public let scrollViewDidScroll = Signal<Void, Never>.pipe()
    
    /// If true, use heightAtIndexPath to store item heights. Most likely
    /// only makes sense in TableViews with autolayouted cells.
    public var useFixedItemHeights = false
    public var heightAtIndexPath: [IndexPath: CGFloat] = [:]
    
    init(stateToItems: @escaping StateToItems = DefaultSingleSectionListViewDatasourceCore.defaultStateToItems) {
        self.stateToItems = stateToItems
    }
    
    public static func defaultStateToItems(state: Datasource.DatasourceState,
                                           valueToItems: @escaping ValueToItems,
                                           loadingItem: (() -> Item)?,
                                           errorItem: ((Datasource.E) -> Item)?,
                                           noResultsItem: (() -> Item)?) -> SingleSectionListItems<Item> {
        return state.singleSectionListItems(valueToItems: valueToItems, loadingItem: loadingItem, errorItem: errorItem, noResultsItem: noResultsItem)
    }
    
    public var builder: Builder {
        return Builder(core: self)
    }
    
}

extension DefaultSingleSectionListViewDatasourceCore {
    
    /// Configures standard components and assumes standard behavior that might be suitable
    /// for most "normal" UITableView use cases:
    ///   - Cached datasource is required (which can also be instantiated without a cache BTW)
    ///   - A response container is shown from which Items are retrieved (configurable via closure)
    ///   - Pull to refresh is enabled (might be configurable later on)
    ///   - When loading, a UIActivityIndicatorView is shown in a item
    ///   - If an error occurs, a specific item is shown
    ///   - If no results are visible, a specific item is shown
    ///   - Items are either selectable or not
    ///   - TableView updates are animated if the view is visible
    ///
    /// Usage: Instantiate and configure with the offered parameters and functions and add the
    /// `tableViewController` to the view hierarchy.
    public struct Builder {
        public typealias Core = DefaultSingleSectionListViewDatasourceCore
        
        public var core: Core
        
        init(core: Core = Core()) {
            self.core = core
        }
        
        /// Has a reasonable default value, so need not be configured.
        @discardableResult
        public func stateToItems(_ closure: @escaping Core.StateToItems) -> Builder {
            var core = self.core
            core.stateToItems = closure
            return core.builder
        }
        
        /// Must be configured to generate actual items.
        @discardableResult
        public func valueToItems(_ closure: @escaping Core.ValueToItems) -> Builder {
            var core = self.core
            core.valueToItems = closure
            return core.builder
        }
        
        /// Must be configured to show items in the view.
        @discardableResult
        public func itemToView(_ closure: @escaping Core.ItemToView) -> Builder {
            var core = self.core
            var itemTypeToViewMapping = [Item.ViewType: ItemViewProducer]()
            Item.ViewType.allCases.forEach { viewType in
                itemTypeToViewMapping[viewType] = closure(viewType)
            }
            core.itemToViewMapping = itemTypeToViewMapping
            return core.builder
        }
        
        /// Is called when an Item is selected (Item.ViewType.isSelectable must be true)
        @discardableResult
        public func itemSelected(_ closure: @escaping ItemSelected) -> Builder {
            var core = self.core
            core.itemSelected = closure
            return core.builder
        }
        
        @discardableResult
        public func loadingItem(_ closure: @escaping () -> Item) -> Builder {
            var core = self.core
            core.loadingItem = closure
            return core.builder
        }
        
        @discardableResult
        public func errorItem(_ closure: @escaping (Datasource.E) -> Item) -> Builder {
            var core = self.core
            core.errorItem = closure
            return core.builder
        }
        
        @discardableResult
        public func noResultsItem(_ closure: @escaping () -> Item) -> Builder {
            var core = self.core
            core.noResultsItem = closure
            return core.builder
        }

    }
    
}
