import UIKit

/// Pure convenience bundle of:
/// - API call datasource whose last success state is retained when a reload
///     occurs (`.retainLastResult` applied).
/// - Disk state persister (for writing success states to disk)
/// - Cached datasource
public struct DefaultCachedAPICallSingleSectionTableViewControllerBundle<DatasourceBundle: CachedAPICallDatasourceBundleProtocol, Cell: DefaultListItem> where DatasourceBundle.APICallDatasource.E == Cell.E {
    
    public typealias CellProducer = DefaultTableViewCellProducer<Cell>
    public typealias TableViewDatasource = DefaultSingleSectionTableViewDatasource<DatasourceBundle.CachedDatasourceConcrete, CellProducer>
    public typealias TableViewController = DefaultSingleSectionTableViewController<DatasourceBundle.CachedDatasourceConcrete, CellProducer>
    
    public let datasourceBundle: DatasourceBundle
    public let tableViewDatasource: TableViewDatasource
    public let tableViewController: TableViewController
    
    public init(datasourceBundle: DatasourceBundle) {
        self.datasourceBundle = datasourceBundle
        self.tableViewDatasource = TableViewDatasource(dataSource: datasourceBundle.cachedDatasource)
        self.tableViewController = TableViewController.init(tableViewDatasource: self.tableViewDatasource)
    }
    
}
