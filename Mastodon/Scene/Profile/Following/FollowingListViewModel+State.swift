//
//  FollowingListViewModel+State.swift
//  Mastodon
//
//  Created by Cirno MainasuK on 2021-11-2.
//

import Foundation
import GameplayKit
import MastodonSDK
import MastodonCore

extension FollowingListViewModel {
    class State: GKState {
        
        let id = UUID()
        
        weak var viewModel: FollowingListViewModel?
        
        init(viewModel: FollowingListViewModel) {
            self.viewModel = viewModel
        }
        
        @MainActor
        func enter(state: State.Type) {
            stateMachine?.enter(state)
        }
    }
}

extension FollowingListViewModel.State {
    class Initial: FollowingListViewModel.State {
        override func isValidNextState(_ stateClass: AnyClass) -> Bool {
            guard let viewModel = viewModel else { return false }
            switch stateClass {
                case is Reloading.Type:
                    return viewModel.userID != nil
                default:
                    return false
            }
        }
    }
    
    class Reloading: FollowingListViewModel.State {
        override func isValidNextState(_ stateClass: AnyClass) -> Bool {
            switch stateClass {
                case is Loading.Type:
                    return true
                default:
                    return false
            }
        }
        
        override func didEnter(from previousState: GKState?) {
            super.didEnter(from: previousState)
            guard let viewModel, let stateMachine else { return }
            
            // reset
            viewModel.accounts = []
            viewModel.relationships = []

            stateMachine.enter(Loading.self)
        }
    }
    
    class Fail: FollowingListViewModel.State {
        
        override func isValidNextState(_ stateClass: AnyClass) -> Bool {
            switch stateClass {
                case is Loading.Type:
                    return true
                default:
                    return false
            }
        }
        
        override func didEnter(from previousState: GKState?) {
            super.didEnter(from: previousState)
            guard let _ = viewModel, let stateMachine = stateMachine else { return }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                stateMachine.enter(Loading.self)
            }
        }
    }
    
    class Idle: FollowingListViewModel.State {
        override func isValidNextState(_ stateClass: AnyClass) -> Bool {
            switch stateClass {
                case is Reloading.Type, is Loading.Type:
                    return true
                default:
                    return false
            }
        }

        override func didEnter(from previousState: GKState?) {
            super.didEnter(from: previousState)

            viewModel?.tableView?.refreshControl?.endRefreshing()
        }
    }
    
    class Loading: FollowingListViewModel.State {
        
        var maxID: String?
        
        override func isValidNextState(_ stateClass: AnyClass) -> Bool {
            switch stateClass {
                case is Fail.Type:
                    return true
                case is Idle.Type:
                    return true
                case is NoMore.Type:
                    return true
                default:
                    return false
            }
        }
        
        override func didEnter(from previousState: GKState?) {
            super.didEnter(from: previousState)
            
            if previousState is Reloading {
                maxID = nil
            }
            
            guard let viewModel, let stateMachine else { return }
            
            guard let userID = viewModel.userID, userID.isEmpty == false else {
                stateMachine.enter(Fail.self)
                return
            }
            
            Task {
                do {
                    let accountResponse = try await APIService.shared.following(
                        userID: userID,
                        maxID: maxID,
                        authenticationBox: viewModel.authenticationBox
                    )

                    if accountResponse.value.isEmpty {
                        await enter(state: NoMore.self)

                        viewModel.accounts = []
                        viewModel.relationships = []
                        return
                    }

                    var hasNewAppend = false

                    let newRelationships = try await APIService.shared.relationship(forAccounts: accountResponse.value, authenticationBox: viewModel.authenticationBox)

                    var accounts = viewModel.accounts

                    for user in accountResponse.value {
                        guard accounts.contains(user) == false else { continue }
                        accounts.append(user)
                        hasNewAppend = true
                    }

                    var relationships = viewModel.relationships

                    for relationship in newRelationships.value {
                        guard relationships.contains(relationship) == false else { continue }
                        relationships.append(relationship)
                    }

                    let maxID = accountResponse.link?.maxID

                    if hasNewAppend, maxID != nil {
                        await enter(state: Idle.self)
                    } else {
                        await enter(state: NoMore.self)
                    }
                    
                    viewModel.accounts = accounts
                    viewModel.relationships = relationships
                    self.maxID = maxID
                } catch {
                    await enter(state: Fail.self)
                }
            }
        }
    }
    
    class NoMore: FollowingListViewModel.State {
        override func isValidNextState(_ stateClass: AnyClass) -> Bool {
            switch stateClass {
                case is Reloading.Type:
                    return true
                default:
                    return false
            }
        }

        override func didEnter(from previousState: GKState?) {
            super.didEnter(from: previousState)

            viewModel?.tableView?.refreshControl?.endRefreshing()
        }
    }
}
