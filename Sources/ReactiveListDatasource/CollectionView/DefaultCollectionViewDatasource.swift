import Foundation
import UIKit
import ReactiveSwift

open class DefaultCollectionViewDatasource<Datasource: DatasourceProtocol, CellViewProducer: CollectionViewCellProducer, Section: ListSection>: NSObject, UICollectionViewDataSource, UICollectionViewDelegate where CellViewProducer.Item : DefaultListItem, CellViewProducer.Item.E == Datasource.E {
    
    public typealias Core = DefaultListViewDatasourceCore<Datasource, CellViewProducer, Section>
    
    private let dataSource: Datasource
    public var core: Core
    
    public lazy var sections: Property<Core.Sections> = {
        return Property<Core.Sections>(initial: Core.Sections.notReady, then: self.sectionsProducer())
    }()
    
    public init(dataSource: Datasource) {
        self.dataSource = dataSource
        self.core = DefaultListViewDatasourceCore()
    }
    
    public func configure(with collectionView: UICollectionView, _ build: (Core.Builder) -> (Core.Builder)) {
        core = build(core.builder).core
        
        core.errorSection = core.errorSection ?? { error in SectionWithItems(Section(), [Core.Item.errorCell(error)]) }
        core.loadingSection = core.loadingSection ?? { SectionWithItems(Section(), [Core.Item.loadingCell]) }
        core.noResultsSection = core.noResultsSection ?? { SectionWithItems(Section(), [Core.Item.noResultsCell]) }
        
        core.itemToViewMapping.forEach { arg in
            let (itemViewType, producer) = arg
            producer.register(itemViewType: itemViewType, at: collectionView)
        }
    }
    
    private func sectionsProducer() -> SignalProducer<Core.Sections, Never> {
        return dataSource.state.map({ [weak self] state -> Core.Sections in
            guard let strongSelf = self else { return Core.Sections.notReady }
            let stateToSections = strongSelf.core.stateToSections
            let valueToSections = strongSelf.core.valueToSections ?? { _ -> [SectionWithItems<Core.Item, Core.Section>]? in
                let errorItem = Core.Item.init(errorMessage: "Set DefaultCollectionViewDatasource.valueToSections")
                return [SectionWithItems.init(Core.Section(), [errorItem])]
            }
            
            return stateToSections(state, valueToSections, strongSelf.core.loadingSection, strongSelf.core.errorSection, strongSelf.core.noResultsSection)
        }).observe(on: UIScheduler())
    }
    
    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        return sections.value.sectionsWithItems?.count ?? 0
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return sections.value.sectionsWithItems?[section].items.count ?? 0
    }
    
    private func isInBounds(indexPath: IndexPath) -> Bool {
        if let sectionsWithItems = sections.value.sectionsWithItems, indexPath.section < sectionsWithItems.count,
            indexPath.item < sectionsWithItems[indexPath.section].items.count {
            return true
        } else {
            return false
        }
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let sectionsWithItems = sections.value.sectionsWithItems, isInBounds(indexPath: indexPath) else {
            print(indexPath)
            print(sections.value.sectionsWithItems?.count ?? 0)
            collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "noSectionsWithItemsCell")
            return collectionView.dequeueReusableCell(withReuseIdentifier: "noSectionsWithItemsCell", for: indexPath)
        }
        
        let cell = sectionsWithItems[indexPath.section].items[indexPath.item]
        if let itemViewProducer = core.itemToViewMapping[cell.viewType] {
            return itemViewProducer.view(containingView: collectionView, item: cell, for: indexPath)
        } else {
            collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "itemToViewMappingMissingCell")
            let fallbackCell = collectionView.dequeueReusableCell(withReuseIdentifier: "itemToViewMappingMissingCell", for: indexPath)
            if fallbackCell.viewWithTag(100) == nil {
                let label = UILabel()
                label.tag = 100
                label.text = "Set DefaultListViewDatasourceCore.itemToViewMapping"
                label.textAlignment = .center
                fallbackCell.contentView.addSubview(label)
                label.translatesAutoresizingMaskIntoConstraints = false
                label.topAnchor.constraint(equalTo: fallbackCell.contentView.topAnchor).isActive = true
                label.leftAnchor.constraint(equalTo: fallbackCell.contentView.leftAnchor).isActive = true
                label.rightAnchor.constraint(equalTo: fallbackCell.contentView.rightAnchor).isActive = true
                label.bottomAnchor.constraint(equalTo: fallbackCell.contentView.bottomAnchor).isActive = true
            }
            return fallbackCell
        }
    }
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let sectionsWithItems = sections.value.sectionsWithItems, isInBounds(indexPath: indexPath) else {
            return
        }
        let sectionWithItems = sectionsWithItems[indexPath.section]
        let cell = sectionWithItems.items[indexPath.item]
        if cell.viewType.isSelectable {
            core.itemSelected?(cell, sectionWithItems.section)
        }
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        core.scrollViewDidScroll.input.send(value: ())
    }
    
}

public extension DefaultCollectionViewDatasource {

    func sectionWithItems(at indexPath: IndexPath) -> SectionWithItems<CellViewProducer.Item, Section>? {
        guard let sectionsWithItems = sections.value.sectionsWithItems,
            indexPath.section < sectionsWithItems.count else { return nil }
        return sectionsWithItems[indexPath.section]
    }
    
    func section(at indexPath: IndexPath) -> Section? {
        return sectionWithItems(at: indexPath)?.section
    }
    
    func item(at indexPath: IndexPath) -> CellViewProducer.Item? {
        guard let sectionWithItems = self.sectionWithItems(at: indexPath) else { return nil }
        guard indexPath.item < sectionWithItems.items.count else { return nil }
        return sectionWithItems.items[indexPath.item]
    }
}

