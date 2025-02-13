//
//  HomeTimelineViewController+DataSourceProvider.swift
//  Mastodon
//
//  Created by MainasuK on 2022-1-13.
//

import UIKit
import MastodonSDK

extension HomeTimelineViewController: DataSourceProvider {
    func item(from source: DataSourceItem.Source) async -> DataSourceItem? {
        var _indexPath = source.indexPath
        if _indexPath == nil, let cell = source.tableViewCell {
            _indexPath = self.indexPath(for: cell)
        }
        guard let indexPath = _indexPath else { return nil }
        
        guard let item = viewModel?.diffableDataSource?.itemIdentifier(for: indexPath) else {
            return nil
        }
        
        switch item {
        case .feed(let feed):
            guard feed.kind == .home else { return nil }
            if let status = feed.status {
                return .status(record: status)
            } else {
                return nil
            }
        default:
            return nil
        }
    }

    func update(status: MastodonStatus, intent: MastodonStatus.UpdateIntent) {
        viewModel?.dataController.update(status: status, intent: intent)
    }

    private func indexPath(for cell: UITableViewCell) -> IndexPath? {
        return tableView.indexPath(for: cell)
    }
}
