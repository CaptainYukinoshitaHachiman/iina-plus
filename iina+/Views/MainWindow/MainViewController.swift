//
//  ViewController.swift
//  iina+
//
//  Created by xjbeta on 2018/7/5.
//  Copyright © 2018 xjbeta. All rights reserved.
//

import Cocoa
import CoreData

private extension NSPasteboard.PasteboardType {
    static let bookmarkRow = NSPasteboard.PasteboardType("bookmark.Row")
}

class MainViewController: NSViewController {

    @IBOutlet weak var mainTabView: NSTabView!
    @objc dynamic var mainTabViewSelectedIndex = 0
    
    var mainWindowController: MainWindowController {
        return view.window?.windowController as! MainWindowController
    }
    
    @IBOutlet weak var bookmarkTableView: NSTableView!
    @IBOutlet var bookmarkArrayController: NSArrayController!
    @objc var bookmarks: NSManagedObjectContext
    @IBAction func sendURL(_ sender: Any) {
        if bookmarkTableView.selectedRow != -1 {
            let url = dataManager.requestData()[bookmarkTableView.selectedRow].url
            searchField.stringValue = url
            searchField.becomeFirstResponder()
            startSearch(self)
        }
    }
    
    
    @IBAction func deleteBookmark(_ sender: Any) {
        if let index = bookmarkTableView.selectedIndexs().first {
            dataManager.deleteBookmark(index)
            bookmarkTableView.reloadData()
        }
    }
    
    @IBAction func addBookmark(_ sender: Any) {
        performSegue(withIdentifier: NSStoryboardSegue.Identifier("showAddBookmarkViewController"), sender: nil)
    }
    
    let dataManager = DataManager()
    required init?(coder: NSCoder) {
        bookmarks = (NSApp.delegate as! AppDelegate).persistentContainer.viewContext
        bookmarks.undoManager = UndoManager()
        super.init(coder: coder)
    }
    
    @IBOutlet weak var bilibiliTableView: NSTableView!
    @IBOutlet var bilibiliArrayController: NSArrayController!
    @objc dynamic var bilibiliCards: [BilibiliCard] = []
    let bilibili = Bilibili()
    
    @IBAction func sendBilibiliURL(_ sender: Any) {
        if bilibiliTableView.selectedRow != -1 {
            let aid = bilibiliCards[bilibiliTableView.selectedRow].aid
            searchField.stringValue = "https://www.bilibili.com/video/av\(aid)"
            searchField.becomeFirstResponder()
            startSearch(self)
        }
    }
    
    @IBOutlet weak var searchField: NSSearchField!
    @IBAction func startSearch(_ sender: Any) {
        let group = DispatchGroup()
        group.enter()
        progressStatusChanged(true)
        let str = searchField.stringValue
        guard str != "", str.isUrl else {
            return
        }
        yougetResult = nil
        isSearching = true
        
        NotificationCenter.default.post(name: .startSearch, object: nil)
        
        Processes.shared.decodeURL(str, { obj in
            DispatchQueue.main.async {
                self.yougetResult = obj
                group.leave()
            }
        }) { error in
            DispatchQueue.main.async {
                if let view = self.suggestionsTableView.view(atColumn: 0, row: 0, makeIfNecessary: false) as? WaitingTableCellView {
                    view.setStatus(.error)
                }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            self.progressStatusChanged(false)
        }
    }
    
    @IBOutlet weak var suggestionsTableView: NSTableView!
    
    var isSearching = false {
        didSet {
            suggestionsTableView.reloadData()
        }
    }
    
    var yougetResult: YouGetJSON? = nil {
        didSet {
            suggestionsTableView.reloadData()
        }
    }
    
    @IBAction func openSelectedSuggestion(_ sender: Any) {
        let row = suggestionsTableView.selectedRow
        guard row != -1 else {
            yougetResult = nil
            isSearching = false
            return
        }
        if let key = yougetResult?.streams.keys.sorted()[row],
            let stream = yougetResult?.streams[key] {
            var urlStr: [String] = []
            if let videoUrl = stream.url {
                urlStr = [videoUrl]
            } else {
                urlStr = stream.src
            }
            
            if let host = URL(string: searchField.stringValue)?.host {
                let title = yougetResult?.title ?? ""
                switch LiveSupportList(raw: host) {
                case .douyu:
                    Processes.shared.openWithPlayer(urlStr, title: title, options: .douyu)
                case .bilibili, .huya, .longzhu, .panda, .pandaXingYan, .quanmin:
                    Processes.shared.openWithPlayer(urlStr, title: title, options: .withoutYtdl)
                case .unsupported:
                    if host == "www.bilibili.com" {
                        Processes.shared.openWithPlayer(urlStr, title: title, options: .bilibili)
                    } else {
                        Processes.shared.openWithPlayer(urlStr, title: title, options: .none)
                    }
                }
            }
        }
        isSearching = false
        yougetResult = nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadBilibiliCards()
        bookmarkArrayController.sortDescriptors = dataManager.sortDescriptors
        bookmarkTableView.backgroundColor = .clear
        bookmarkTableView.registerForDraggedTypes([.bookmarkRow])
        bookmarkTableView.draggingDestinationFeedbackStyle = .gap
        NotificationCenter.default.addObserver(self, selector: #selector(reloadTableView), name: .reloadMainWindowTableView, object: nil)
        NotificationCenter.default.addObserver(forName: .sideBarSelectionChanged, object: nil, queue: .main) {
            if let userInfo = $0.userInfo as? [String: String],
                let str = userInfo["selectedItem"],
                let item = SidebarItem(raw: str) {
                switch item {
                case .live:
                    self.mainTabView.selectTabViewItem(at: 0)
                case .bilibili:
                    self.mainTabView.selectTabViewItem(at: 1)
                case .search:
                    self.mainTabView.selectTabViewItem(at: 2)
                default: break
                }
            }
        }
        NotificationCenter.default.addObserver(self, selector: #selector(scrollViewDidScroll(_:)), name: NSScrollView.didLiveScrollNotification, object: bilibiliTableView.enclosingScrollView)
    }
    
    
    
    var canLoadMoreBilibiliCards = true
    
    @objc func scrollViewDidScroll(_ notification: Notification) {
        guard canLoadMoreBilibiliCards else { return }

        if let scrollView = notification.object as? NSScrollView {
            let visibleRect = scrollView.contentView.documentVisibleRect
            let documentRect = scrollView.contentView.documentRect
            if documentRect.height - visibleRect.height - visibleRect.origin.y < 10 {
                loadBilibiliCards(.history)
            }
        }
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    @objc func reloadTableView() {
        switch mainTabViewSelectedIndex {
        case 0:
            bookmarkTableView.reloadData()
        case 1:
            loadBilibiliCards()
        default:
            break
        }
    }
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let vc = segue.destinationController as? AddBookmarkViewController {
            vc.dismiss = {
                self.dismiss(vc)
            }
        }
    }
    
    func loadBilibiliCards(_ action: BilibiliDynamicAction = .init) {
        var dynamicID = -1
        let group = DispatchGroup()
        
        switch action {
        case .history:
            dynamicID = bilibiliCards.last?.dynamicId ?? -1
        case .new:
            dynamicID = bilibiliCards.first?.dynamicId ?? -1
        default: break
        }
        
        canLoadMoreBilibiliCards = false
        progressStatusChanged(!canLoadMoreBilibiliCards)
        group.enter()
        bilibili.dynamicList(action, dynamicID, { cards in
            DispatchQueue.main.async {
                switch action {
                case .init:
                    self.bilibiliCards = cards
                case .history:
                    self.bilibiliCards.append(contentsOf: cards)
                case .new:
                    self.bilibiliCards.insert(contentsOf: cards, at: 0)
                default: break
                }
                group.leave()
            }
        }) { re in
            do {
                let _ = try re()
            } catch let error {
                Logger.log("Get bilibili dynamicList error: \(error)")
                group.leave()
            }
        }
        group.notify(queue: .main) {
            self.canLoadMoreBilibiliCards = true
            self.progressStatusChanged(!self.canLoadMoreBilibiliCards)
        }
    }
    
    func progressStatusChanged(_ inProgress: Bool) {
        NotificationCenter.default.post(name: .progressStatusChanged, object: nil, userInfo: ["inProgress": inProgress])
    }
    

}

extension MainViewController: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        switch tableView {
        case bookmarkTableView:
            return dataManager.requestData().count
        case bilibiliTableView:
            return tableView.numberOfRows
        case suggestionsTableView:
            if let obj = yougetResult {
                return obj.streams.count
            } else if isSearching {
                return 1
            }
        default:
            break
        }
        return 0
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        switch tableView {
        case bookmarkTableView:
            let str = dataManager.requestData()[row].url
            if let url = URL(string: str) {
                switch LiveSupportList(raw: url.host) {
                case .unsupported:
                    return 20
                default:
                    return 55
                }
            }
        case bilibiliTableView:
            return tableView.rowHeight
        case suggestionsTableView:
            return 30
        default:
            break
        }
        return 0
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        switch tableView {
        case bookmarkTableView:
            let str = dataManager.requestData()[row].url
            if let url = URL(string: str) {
                switch LiveSupportList(raw: url.host) {
                case .unsupported:
                    if let view = tableView.makeView(withIdentifier: .liveUrlTableCellView, owner: nil) as? NSTableCellView {
                        view.textField?.stringValue = str
                        return view
                    }
                default:
                    if let view = tableView.makeView(withIdentifier: .liveStatusTableCellView, owner: nil) as? LiveStatusTableCellView {
//                        view.resetInfo()
                        getInfo(url, { liveInfo in
                            view.setInfo(liveInfo)
                        }) { re in
                            do {
                                let _ = try re()
                            } catch let error {
                                Logger.log("Get live status error: \(error)")
                                view.setErrorInfo(str)
                            }
                        }
                        return view
                    }
                }
            }
        case bilibiliTableView:
            if let view = tableView.makeView(withIdentifier: .bilibiliCardTableCellView, owner: nil) as? BilibiliCardTableCellView {
                return view
            }
        case suggestionsTableView:
            if let obj = yougetResult {
                if let view = tableView.makeView(withIdentifier: .suggestionsTableCellView, owner: self) as? SuggestionsTableCellView {
                    view.textField?.stringValue = obj.streams.keys.sorted()[row]
                    return view
                }
            } else {
                if let view = tableView.makeView(withIdentifier: .waitingTableCellView, owner: self) as? WaitingTableCellView {
                    view.setStatus(.waiting)
                    return view
                }
            }
        default:
            break
        }
        return nil
    }
    
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("MainWindowTableRowView"), owner: self) as? MainWindowTableRowView
        
    }
    
    
    func tableView(_ tableView: NSTableView, draggingSession session: NSDraggingSession, willBeginAt screenPoint: NSPoint, forRowIndexes rowIndexes: IndexSet) {
        guard let row: Int = rowIndexes.first,
            let view = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? LiveStatusTableCellView else {
                return
        }
        let image = view.screenshot()

        session.enumerateDraggingItems(options: .concurrent, for: tableView, classes: [NSPasteboardItem.self], searchOptions: [:]) { draggingItem, idx, stop in
            
            var rect = NSRect(origin: draggingItem.draggingFrame.origin, size: image.size)
            rect.origin.y -= rect.size.height
            rect.origin.y += draggingItem.draggingFrame.size.height
            draggingItem.draggingFrame = rect

            let backgroundImageComponent = NSDraggingImageComponent(key: NSDraggingItem.ImageComponentKey(rawValue: "background"))
            backgroundImageComponent.contents = image
            backgroundImageComponent.frame = NSRect(origin: NSZeroPoint, size: image.size)
            draggingItem.imageComponentsProvider = {
                return [backgroundImageComponent]
            }
        }
    }
    

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        guard tableView == bookmarkTableView else {
            return nil
        }
        let item = NSPasteboardItem()
        item.setString(String(row), forType: .bookmarkRow)
        return item
    }
    
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        if dropOperation == .above {
            return .move
        }
        return []
    }
    
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {

        var oldRows: [Int] = []
        info.enumerateDraggingItems(options: [], for: tableView, classes: [NSPasteboardItem.self], searchOptions: [:]) {
            (draggingItem, idx, stop) in
            guard let item = draggingItem.item as? NSPasteboardItem else { return }
            guard let rowStr = item.string(forType: .bookmarkRow) else { return }
            guard let row = Int(rowStr) else { return }
            oldRows.append(row)
        }
        
        guard oldRows.count == 1, let oldRow = oldRows.first else {
            return false
        }
        
        tableView.beginUpdates()
        if oldRow < row {
            dataManager.moveBookmark(at: oldRow, to: row - 1)
            tableView.moveRow(at: oldRow, to: row - 1)
        } else {
            dataManager.moveBookmark(at: oldRow, to: row)
            tableView.moveRow(at: oldRow, to: row)
        }
        tableView.endUpdates()

        return true
    }
    

}

extension MainViewController: NSSearchFieldDelegate {
    func searchFieldDidStartSearching(_ sender: NSSearchField) {
        print(#function, sender.stringValue)
    }
    
    func searchFieldDidEndSearching(_ sender: NSSearchField) {
        print(#function, sender.stringValue)
    }
}

extension NSTableView {
    func selectedIndexs() -> IndexSet {
        if clickedRow != -1 {
            if selectedRowIndexes.contains(clickedRow) {
                return selectedRowIndexes
            } else {
                return IndexSet(integer: clickedRow)
            }
        } else {
            return selectedRowIndexes
        }
    }
}
