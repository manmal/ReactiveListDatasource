import Foundation
import Dwifft

public extension ListSections {
    var sectionedValues: SectionedValues<Section, Item> {
        return SectionedValues((sectionsWithItems ?? []).map({ ($0.section, $0.items) }))
    }
}
