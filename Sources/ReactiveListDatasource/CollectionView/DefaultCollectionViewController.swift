import Foundation
import ReactiveSwift
import Dwifft
import UIKit

open class DefaultCollectionViewController<Datasource: DatasourceProtocol, CellViewProducer: TableViewCellProducer> : UIViewController where CellViewProducer.Item : DefaultListItem, CellViewProducer.Item.E == Datasource.E {
    
    public typealias Cell = CellViewProducer.Item
    public typealias Cells = SingleSectionListItems<Cell>
    public typealias TableViewDatasource = DefaultSingleSectionTableViewDatasource<Datasource, CellViewProducer>
    
    open var refreshControl: UIRefreshControl?
    
    public lazy var tableView: UITableView = {
        let v = UITableView(frame: .zero, style: self.tableViewStyle)
        self.view.addSubview(v)
        v.translatesAutoresizingMaskIntoConstraints = false
        v.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
        v.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
        v.rightAnchor.constraint(equalTo: self.view.rightAnchor).isActive = true
        v.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
        let footerView = UIView(frame: .zero)
        v.tableFooterView = footerView
        
        return v
    }()
    
    public var addEmptyViewAboveTableView = true // To prevent tableview insets bugs in iOS10
    public var tableViewStyle = UITableView.Style.plain
    public var estimatedRowHeight: CGFloat = 75
    public var supportPullToRefresh = true
    public var animateTableViewUpdates = true
    public var onPullToRefresh: (() -> ())?
    
    open var isViewVisible: Bool {
        return viewIfLoaded?.window != nil && view.alpha > 0.001
    }
    
    private let tableViewDatasource: TableViewDatasource
    private var tableViewDiffCalculator: SingleSectionTableViewDiffCalculator<Cell>?
    
    public init(tableViewDatasource: TableViewDatasource) {
        self.tableViewDatasource = tableViewDatasource
        super.init(nibName: nil, bundle: nil)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("Storyboards cannot be used with this class")
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        extendedLayoutIncludesOpaqueBars = true
        
        if addEmptyViewAboveTableView {
            view.addSubview(UIView())
        }
        
        tableView.delegate = tableViewDatasource
        tableView.dataSource = tableViewDatasource
        tableView.tableFooterView = UIView(frame: .zero)
        
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = estimatedRowHeight
        
        if #available(iOS 11.0, *) {
            tableView.insetsContentViewsToSafeArea = true
        }
        
        if supportPullToRefresh {
            let refreshControl = UIRefreshControl()
            refreshControl.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)
            tableView.addSubview(refreshControl)
            tableView.sendSubviewToBack(refreshControl)
            self.refreshControl = refreshControl
        }
        
        // Update table with most current cells
        tableViewDatasource.cells.producer
            .skipRepeats()
            .combinePrevious()
            .startWithValues { [weak self] arg in
                let (previous, next) = arg
                self?.updateCells(previous: previous, next: next)
        }
    }
    
    private func updateCells(previous: Cells, next: Cells) {
        switch previous {
        case let .readyToDisplay(previousCells) where isViewVisible && animateTableViewUpdates:
            if self.tableViewDiffCalculator == nil {
                // Use previous cells as initial values such that "next" cells are
                // inserted with animations
                self.tableViewDiffCalculator = self.createTableViewDiffCalculator(initial: previousCells)
            }
            self.tableViewDiffCalculator?.rows = next.items ?? []
        case .readyToDisplay, .notReady:
            // Animations disabled or view invisible - skip animations.
            self.tableViewDiffCalculator = nil
            DispatchQueue.main.async { [weak self] in
                self?.tableView.reloadData()
            }
        }
    }
    
    private func createTableViewDiffCalculator(initial: [Cell]) -> SingleSectionTableViewDiffCalculator<Cell> {
        let c = SingleSectionTableViewDiffCalculator<Cell>(tableView: tableView, initialRows: initial)
        c.insertionAnimation = .fade
        c.deletionAnimation = .fade
        return c
    }
    
    @objc func pullToRefresh() {
        onPullToRefresh?()
    }
    
}
