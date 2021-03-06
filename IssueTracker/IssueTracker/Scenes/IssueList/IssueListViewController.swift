//
//  IssueListViewController.swift
//  IssueTracker
//
//  Created by Sue Cho on 2020/10/29.
//

import UIKit

//MARK:- Typealias
typealias IssueViewModel = ListIssues.FetchIssues.ViewModel.DisplayedIssue

protocol IssueListDisplayLogic: class {
    func displayOpenIssues(viewModel: ListIssues.FetchIssues.ViewModel)
    func displayUsers(viewModel: ListUsers.FetchUsers.ViewModel)
    func displayFetchedLabels(viewModel: ListLabels.FetchLists.ViewModel)
    func displayFetchedMilestone(viewModel: ListMilestones.FetchLists.ViewModel)
    func displayFetchedComment(viewModel: ListComment.FetchDetail.ViewModel)
    func didOpenCloseIssue(fetch : ListIssues.FetchCategory)
}

final class IssueListViewController: UIViewController {
    
    // MARK:- IBOutlets
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var newIssueButton: CustomAddButton!
    @IBOutlet weak var closeIssueButton: UIButton!
    @IBOutlet weak var issueListCollectionView: UICollectionView!
    @IBOutlet weak var openCloseSwitch: UISwitch!
    @IBOutlet weak var filterButton: CustomAddButton!
    
    // MARK:- Properties
    private let userId = UserDefaults.standard.object(forKey: "ID") as! Int
    var interactor: IssueListBusinessLogic?
    var detailWorker = IssueDetailWorker(dataManager: IssueDetailDataManager())
    var router: (NSObjectProtocol & IssueListRoutingLogic & IssueDetailDataPassing)?
    
    private var displayedIssues: [IssueViewModel] = []
    private var filteredIssues: [IssueViewModel] = []
    private var displayedUsers: [ListUsers.FetchUsers.ViewModel.DisplayedUser] = []
    private var displayedLabels: [ListLabels.FetchLists.ViewModel.DisplayedLabel] = []
    private var displayedMilestones: [ListMilestones.FetchLists.ViewModel.DisplayedMilestone] = []
    private var displayedComments: [comment] = []
    
    private var filterDict: [FilterCategory: Int] = [.Author : 0, .Label : 0, .Milestone : 0, .Assignee : 0]
    
    var config = UICollectionLayoutListConfiguration(appearance: .plain)
    let searchController = UISearchController(searchResultsController: nil)
    
    override var isEditing: Bool {
        willSet {
            if newValue { setupEditMode() }
            else { setupNormalMode() }
        }
    }
    
    var selectedItems: Int = 0 {
        willSet {
            if isEditing {
                titleLabel.text = "\(newValue) Selected"
                if newValue > 0 {
                    closeIssueButton.isEnabled = true
                    navigationItem.leftBarButtonItem?.title = "Deselect All"
                } else {
                    closeIssueButton.isEnabled = false
                    navigationItem.leftBarButtonItem?.title = "Select All"
                }
            }
        }
    }
    var isSearchBarEmpty: Bool {
        return searchController.searchBar.text?.isEmpty ?? true
    }
    var isFiltering: Bool {
        let searchBarScopeIsFiltering = searchController.searchBar.selectedScopeButtonIndex != 0
        return searchController.isActive && (!isSearchBarEmpty || searchBarScopeIsFiltering)
    }
    
    // MARK:- Object Lifecycle
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    // MARK:- Routing
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let scene = segue.identifier {
            let selector = NSSelectorFromString("routeTo\(scene)WithSegue:")
            if let router = router, router.responds(to: selector) {
                router.perform(selector, with: segue)
            }
        }
    }
    
    // MARK:- View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSearchController()
        setupOpenCollectionview()
        setupNormalMode()
        setupInteraction()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if openCloseSwitch.isOn { fetchIssues(request: .Open) }
        else { fetchIssues(request: .Closed) }
    }
    
    //MARK:- IBActions
    @IBAction func onEditButtonPressed(_ sender: Any) {
        isEditing = !isEditing
        issueListCollectionView.isEditing = isEditing
    }
    
    @IBAction func onNavigationLeftBarBtnPressed(_ sender: Any) {
        if isEditing {
            if selectedItems > 0 { deselectAllItems() }
            else { selectAllItems() }
        }
    }
    
    @IBAction func selectedClosebutton(_ sender: Any) {
        guard let selectedItemsIndexPath = issueListCollectionView.indexPathsForSelectedItems else { return }
        selectedItemsIndexPath.forEach({ indexPath in
            closeIssue(at: indexPath)
        })
    }
    
    @IBAction func switchAction(_ sender: UISwitch) {
        if openCloseSwitch.isOn {
            fetchIssues(request: .Open)
            setupOpenCollectionview()
        }
        else {
            fetchIssues(request: .Closed)
            setupClosedCollectionView()
        }
    }
    
    private func selectAllItems() {
        let numberOfItems = issueListCollectionView.numberOfItems(inSection: 0)
        for cellPos in 0..<numberOfItems {
            issueListCollectionView.selectItem(at: IndexPath(item: cellPos, section: 0), animated: false, scrollPosition: [])
        }
        selectedItems = numberOfItems
    }
    
    private func deselectAllItems() {
        let numberOfItems = issueListCollectionView.numberOfItems(inSection: 0)
        for cellPos in 0..<numberOfItems {
            selectedItems -= 1
            issueListCollectionView.deselectItem(at: IndexPath(item: cellPos, section: 0), animated: false)
        }
        selectedItems = 0
    }
    
}

// MARK:- Setup
extension IssueListViewController {
    
    private func setup() {
        let viewController = self
        let interactor = IssueListInteractor()
        let presenter = IssueListPresenter()
        let router = IssueListRouter()
        viewController.interactor = interactor
        viewController.router = router
        interactor.presenter = presenter
        presenter.viewController = viewController
        router.viewController = viewController
    }
    
    private func setupOpenCollectionview() {
        config.trailingSwipeActionsConfigurationProvider = { [unowned self] (indexPath) in
            let close = UIContextualAction(style: .normal, title: "Close") { (action, view, completion) in
                closeIssue(at: indexPath)
            }
            close.backgroundColor = .systemPink
            return UISwipeActionsConfiguration(actions: [close])
        }
        createListLayout()
    }
    
    private func setupClosedCollectionView() {
        config.trailingSwipeActionsConfigurationProvider = { [unowned self] (indexPath) in
            let open = UIContextualAction(style: .normal, title: "Open") { (action, view, completion) in
                openIssue(at: indexPath)
            }
            open.backgroundColor = .systemGreen
            return UISwipeActionsConfiguration(actions: [open])
        }
        createListLayout()
    }
    
    private func createListLayout() {
        let layout = UICollectionViewCompositionalLayout.list(using: config)
        issueListCollectionView.collectionViewLayout = layout
        issueListCollectionView.delegate = self
        issueListCollectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }
    
    private func setupNormalMode() {
        selectedItems = 0
        let tabbarHeight = tabBarController?.tabBar.frame.height ?? 0
        tabBarController?.tabBar.frame.origin.y = view.frame.height - tabbarHeight
        titleLabel.text = "Issue"
        newIssueButton.isHidden = false
        filterButton.isHidden = true
        navigationItem.rightBarButtonItem?.title = "Edit"
        navigationItem.leftBarButtonItem?.title = ""
    }
    
    private func setupEditMode() {
        let tabbarHeight = self.tabBarController!.tabBar.frame.height
        self.tabBarController!.tabBar.frame.origin.y = view.frame.height + tabbarHeight
        newIssueButton.isHidden = true
        filterButton.isHidden = true
        closeIssueButton.isEnabled = false
        titleLabel.text = "0 Selected"
        navigationItem.rightBarButtonItem?.title = "Cancel"
        navigationItem.leftBarButtonItem?.title = "Select All"
        issueListCollectionView.allowsMultipleSelectionDuringEditing = true
        issueListCollectionView.allowsSelection = true
    }
    
    private func setupSearchController() {
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search Issues"
        navigationItem.searchController = searchController
        definesPresentationContext = true
        
        searchController.searchBar.scopeButtonTitles = FilterScope.allCases.map({ $0.rawValue })
        searchController.searchBar.delegate = self
        searchController.delegate = self
        searchController.searchBar.delegate = self
        searchController.searchBar.searchTextField.delegate = self
    }
    
    private func setupInteraction() {
        let interaction = UIContextMenuInteraction(delegate: self)
        filterButton.addInteraction(interaction)
    }
}

// MARK:- Implement IssueListDisplayLogic
extension IssueListViewController: IssueListDisplayLogic {
    
    func displayOpenIssues(viewModel: ListIssues.FetchIssues.ViewModel) {
        displayedIssues = viewModel.displayedIssues
        issueListCollectionView.reloadData()
    }
    
    func displayUsers(viewModel: ListUsers.FetchUsers.ViewModel) {
        displayedUsers = viewModel.displayedUser
    }
    
    func displayFetchedMilestone(viewModel: ListMilestones.FetchLists.ViewModel) {
        displayedMilestones = viewModel.displayedMilestones
    }
    
    func displayFetchedLabels(viewModel: ListLabels.FetchLists.ViewModel) {
        displayedLabels = viewModel.displayedLabels
    }
    
    func displayFetchedComment(viewModel: ListComment.FetchDetail.ViewModel) {
        displayedComments = viewModel.displayedComment
    }
    
    func didOpenCloseIssue(fetch : ListIssues.FetchCategory) {
        fetchIssues(request: fetch)
    }
    
    private func fetchUsers() {
        let request = ListUsers.FetchUsers.Request()
        interactor?.fetchUsers(request: request)
    }
    
    private func fetchLabels() {
        let request = ListLabels.FetchLists.Request()
        interactor?.fetchLabels(request: request)
    }
    
    private func fetchMilestones() {
        let request = ListMilestones.FetchLists.Request()
        interactor?.fetchMilestones(request: request)
    }
    
    private func fetchComments(id: Int) {
        let request = ListComment.FetchDetail.Request(issueId: id)
        interactor?.fetchComments(request: request)
    }
    
    // Fetch, Open, Close, Delete Issue
    private func fetchIssues(request: ListIssues.FetchCategory) {
        let request = ListIssues.FetchIssues.Request(request: request)
        interactor?.fetchIssues(request: request)
    }
    
    private func openIssue(at indexPath: IndexPath) {
        let issueId = displayedIssues[indexPath.item].issueId
        interactor?.openIssue(request: ListIssues.OpenIssue.Request(issueId: issueId))
    }
    
    private func closeIssue(at indexPath: IndexPath) {
        selectedItems -= 1
        let issueId = displayedIssues[indexPath.item].issueId
        interactor?.closeIssue(request: ListIssues.CloseIssue.Request(issueId: issueId))
    }
    
    private func deleteIssue(at indexPath: IndexPath) {
        // TODO:
        // update할 테이블이 너무 많아서 BE에 부담가는 듯
        // delete issue는 후순위로 미루기
    }
    
}

// MARK:- UISearchResultUpdating
extension IssueListViewController: UISearchResultsUpdating {
    
    func updateSearchResults(for searchController: UISearchController) {
        let searchBar = searchController.searchBar
        let scope = FilterScope(rawValue: searchBar.scopeButtonTitles![searchBar.selectedScopeButtonIndex])
        filterContentForSearchText(searchBar.text!, scope: scope)
    }
    
    func filterContentForSearchText(_ searchText: String, scope: FilterScope? = nil) {
        filteredIssues = displayedIssues.filter({ (issue: IssueViewModel) -> Bool in
            let doesScopeMatch = filterMatchingScope(issue: issue, scope: scope)
            if isSearchBarEmpty {
                return doesScopeMatch
            } else {
                return doesScopeMatch && issue.title.lowercased().contains(searchText.lowercased())
            }
        })
        issueListCollectionView.reloadData()
    }
    
    private func filterMatchingScope(issue: IssueViewModel, scope: FilterScope?) -> Bool {
        guard let scope = scope else { return false }
        switch scope {
        case .All : return true
        case .Created :
            if issue.userId == userId { return true }
            return false
        case .Assigned :
            guard let assign = issue.assign else { return false }
            for assignee in assign {
                if assignee.userId == userId { return true }
                else { return false }
            }
            return false
        case .Commented :
            for commentDetail in displayedComments {
                // TODO:
                // 문제 : fetch가 비동기적으로 일어나면서 완료 이전에 if문 실행되어 모두 false
                // 예상해결방법 : ??
                fetchComments(id: issue.issueId)
                if commentDetail.userId == userId { return true }
            }
            return false
        }
    }
    
}

// MARK:- UISearchControllerDelegate
extension IssueListViewController: UISearchControllerDelegate {
    
    func didPresentSearchController(_ searchController: UISearchController) {
        filterButton.isHidden = false
        openCloseSwitch.isHidden = true
        newIssueButton.isHidden = true
    }
    
    func didDismissSearchController(_ searchController: UISearchController) {
        fetchIssues(request: .Open)
        filterButton.isHidden = true
        openCloseSwitch.isHidden = false
        newIssueButton.isHidden = false
    }
}

// MARK:- UISearchBarDelegate
extension IssueListViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        if selectedScope > 0 {
            searchBar.searchTextField.endEditing(true)
        }
        let scope = FilterScope(rawValue: searchBar.scopeButtonTitles![selectedScope])
        filterContentForSearchText(searchBar.text!, scope: scope)
    }
}

// MARK:- UIContextMenuInteractionDelegate
extension IssueListViewController: UIContextMenuInteractionDelegate {
    
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        fetchUsers()
        fetchLabels()
        fetchMilestones()
        return UIContextMenuConfiguration(
            identifier: nil,
            previewProvider: nil,
            actionProvider: { [unowned self] _ in
                let children = [filterAuthor(), filterLabel(), filterMilestone(), filterAssignee()]
                return UIMenu(title: "Select Filter Options", children: children)
            }
        )
    }
    
    func filterAuthor() -> UIMenu {
        var authors = [String]()
        var authorIDs = [Int]()
        displayedUsers.forEach({ user in
            authors.append(user.name)
            authorIDs.append(user.id)
        })
        let chooseAuthor = authors.enumerated().map({ (idx, author) in
            return UIAction(
                title: author,
                image: nil,
                identifier: UIAction.Identifier("\(authorIDs[idx])"),
                handler: { [unowned self] _ in
                    filterMenuPressed(type: .Author, id: authorIDs[idx])
                })
        })
        return UIMenu(
            title: "Author",
            image: UIImage(systemName: "chevron.right"),
            children: chooseAuthor)
    }
    
    func filterLabel() -> UIMenu {
        var labels = [String]()
        var labelIDs = [Int]()
        displayedLabels.forEach({ label in
            labels.append(label.name)

        })
        let chooseLabel = labels.enumerated().map({ (idx, label) in
            return UIAction(
                title: label,
                image: nil,
                identifier: UIAction.Identifier(label),
                attributes: UIMenuElement.Attributes.disabled,
                handler: { [unowned self] _ in
                    filterMenuPressed(type: .Label, id: labelIDs[idx])
                })
        })
        return UIMenu(
            title: "Label",
            image: UIImage(systemName: "chevron.right"),
            children: chooseLabel)
    }
    
    func filterMilestone() -> UIMenu {
        var milestones = [String]()
        var milestoneIDs = [Int]()
        displayedMilestones.forEach({ milestone in
            milestones.append(milestone.title)
            milestoneIDs.append(milestone.id)
        })
        let chooseMilestone = milestones.enumerated().map({ (idx, milestone) in
            return UIAction(
                title: milestone,
                image: nil,
                identifier: UIAction.Identifier(milestone),
                attributes: UIMenuElement.Attributes.disabled,
                handler: { [unowned self] _ in
                    filterMenuPressed(type: .Milestone, id: milestoneIDs[idx])
                })
        })
        return UIMenu(
            title: "Milestone",
            image: UIImage(systemName: "chevron.right"),
            children: chooseMilestone)
    }
    
    func filterAssignee() -> UIMenu {
        var assignees = [String]()
        var assigneeIDs = [Int]()
        displayedUsers.forEach({ assignee in
            assignees.append(assignee.name)
            assigneeIDs.append(assignee.id)
        })
        let chooseAssignee = assignees.enumerated().map({ (idx, assignee) in
            return UIAction(
                title: assignee,
                image: nil,
                identifier: UIAction.Identifier(assignee),
                attributes: UIMenuElement.Attributes.disabled,
                handler: { [unowned self] _ in
                    filterMenuPressed(type: .Assignee, id: assigneeIDs[idx])
                })
        })
        return UIMenu(
            title: "Assignee",
            image: UIImage(systemName: "chevron.right"),
            children: chooseAssignee)
    }
    
    private func filterMenuPressed(type: FilterCategory, id: Int) {
        switch type {
        case .Author:
            print("AUTHOR ID : \(id)")
            guard let currentAuthor = filterDict[.Author] else { return }
            if currentAuthor == id { filterDict.updateValue(0, forKey: .Author) }
            else { filterDict.updateValue(id, forKey: .Author) }
        case .Label:
            print("LABEL ID : \(id)")
            guard let currentLabel = filterDict[.Label] else { return }
            if currentLabel == id { filterDict.updateValue(0, forKey: .Label) }
            else { filterDict.updateValue(id, forKey: .Label) }
        case .Milestone:
            print("MILESTONE ID : \(id)")
            guard let currentMilestone = filterDict[.Milestone] else { return }
            if currentMilestone == id { filterDict.updateValue(0, forKey: .Milestone) }
            else { filterDict.updateValue(id, forKey: .Milestone) }
        case .Assignee:
            print("ASSIGNEE ID : \(id)")
            guard let currentAssignee = filterDict[.Assignee] else { return }
            if currentAssignee == id { filterDict.updateValue(0, forKey: .Assignee) }
            else { filterDict.updateValue(id, forKey: .Assignee) }
        }
        filterIssues()
    }
    
    private func filterIssues() {
        filteredIssues = displayedIssues.filter({ (issue: IssueViewModel) -> Bool in
            return compareOptionWithFilterDict(issue: issue)
        })
        displayedIssues = filteredIssues
        issueListCollectionView.reloadData()
    }
    
    private func compareOptionWithFilterDict(issue: IssueViewModel) -> Bool {
        guard let filterAuthor = filterDict[.Author],
              let filterLabel = filterDict[.Label],
              let filterMilestone = filterDict[.Milestone],
              let filterAssignee = filterDict[.Assignee] else { return false }
        
        // ... api가 꼬였으므로 lable, milestone, assignee filter 몬해~
        if filterAuthor > 0 && filterAuthor != issue.userId { return false }
        else { return true }
    }
    
}

// MARK:- Data Source
extension IssueListViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if isFiltering {
            return filteredIssues.count
        }
        return displayedIssues.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let identifier = "issueCell"
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: identifier, for: indexPath) as? IssueListCollectionViewCell else {
            return UICollectionViewCell()
        }
        cell.setupComponents()
        var displayedIssue: IssueViewModel
        if isFiltering { displayedIssue = filteredIssues[indexPath.item] }
        else { displayedIssue = displayedIssues[indexPath.item] }
        cell.titleLabel.text = displayedIssue.title
        cell.descriptionLabel.text = displayedIssue.content
        if let labels: [IssueLabel] = displayedIssue.label {
            labels.enumerated().forEach({ (idx, labelData) in
                let projectLabel: UIButton = cell.labelButtonCollection[idx]
                projectLabel.setTitle(labelData.labelName, for: .normal)
                cell.configureLabelButton(label: projectLabel, hexString: labelData.labelColor)
            })
        }
        if let milestoneText = displayedIssue.milestone {
            cell.milestoneLabel.setTitle(milestoneText, for: .normal)
            cell.configureMilestone()
        }
        
        cell.accessories = [.multiselect(displayed: .whenEditing, options: .init()) ]
        return cell
    }
    
}

// MARK:- UICollectionViewDelegate
extension IssueListViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if isEditing {
            selectedItems += 1
        } else {
            let pushVC = self.storyboard?.instantiateViewController(withIdentifier: "IssueDetail") as! IssueDetailViewController
            router?.issueDetailData = displayedIssues[indexPath.row].issueId
            router?.routeToIssue(destinationVC: pushVC)
            self.navigationController?.pushViewController(pushVC, animated: true)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        if isEditing {
            selectedItems -= 1
        }
    }
    
}

// MARK:- UITextFieldDelegate
extension IssueListViewController: UITextFieldDelegate { }
