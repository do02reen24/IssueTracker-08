//
//  MilestoneListModels.swift
//  IssueTracker
//
//  Created by kimn on 2020/11/01.
//

import Foundation

struct Milestone: Decodable {
    var id: Int
    var title: String
    var dueDate: String?
    var content: String?
    var isOpen: Int
    var openIssue: Int
    var closeIssue: Int
}

enum milestoneDetail {
    enum FetchLists {
        struct Request { var id: Int }
        struct Response {
            var milestones: Milestone
        }
        struct ViewModel {
            struct DisplayedMilestone {
                var id: Int
                var title: String
                var dueDate: String?
                var content: String
                var openIssue: Int
                var closeIssue: Int
            }
            var displayedMilestones: DisplayedMilestone
        }
    }
}

enum ListMilestones {
    enum FetchLists {
        struct Request { }
        struct Response {
            var milestones: [Milestone]
        }
        struct ViewModel {
            struct DisplayedMilestone {
                var id: Int
                var title: String
                var dueDate: String?
                var content: String
                var openIssue: Int
                var closeIssue: Int
            }
            var displayedMilestones: [DisplayedMilestone]
        }
    }
}

enum CreateMilestones {
    struct MilestoneFormField: Encodable {
        var title: String
        var dueDate: String?
        var content: String?
    }
    
    enum CreateMilestone {
        struct Request { var milestone: MilestoneFormField }
        struct Response { var status: String }
        struct ViewModel {
            struct DisplayedAlert {
                var title: String
                var message: String
            }
            var displayedAlert: DisplayedAlert
        }
    }
    
    enum EditMilestone {
        struct Request {
            var index: Int
            var milestoneFormFileds: MilestoneFormField
        }
        struct Response { var status: String }
        struct ViewModel {
            struct DisplayedAlert {
                var title: String
                var message: String
            }
            var displayedAlert: DisplayedAlert
        }
    }
}

enum DeleteMilestones {
    struct MilestoneFormField {
        var milestoneId: Int
    }
    
    enum DeleteMilestone {
        struct Request { var milestone: MilestoneFormField }
        struct Response { var status: String }
        struct ViewModel {
            struct DisplayedAlert {
                var title: String
                var message: String
            }
            var displayedAlert: DisplayedAlert
        }
    }
}
