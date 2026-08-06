class AddIssueStatusHistoryIndexes < ActiveRecord::Migration[6.1]
  def up
    issue_from_index = 'index_status_histories_on_issue_and_from'
    unless index_exists?(:issue_status_histories, %i[issue_id from], name: issue_from_index)
      add_index :issue_status_histories, %i[issue_id from], name: issue_from_index
    end
    add_index :issue_status_histories, :journal_id unless index_exists?(:issue_status_histories, :journal_id)
    add_index :issue_status_histories, :user_id unless index_exists?(:issue_status_histories, :user_id)
    remove_index :issue_status_histories, :issue_id if index_exists?(:issue_status_histories, :issue_id)
  end

  def down
    add_index :issue_status_histories, :issue_id unless index_exists?(:issue_status_histories, :issue_id)
    remove_index :issue_status_histories, :user_id if index_exists?(:issue_status_histories, :user_id)
    remove_index :issue_status_histories, :journal_id if index_exists?(:issue_status_histories, :journal_id)

    issue_from_index = 'index_status_histories_on_issue_and_from'
    if index_exists?(:issue_status_histories, %i[issue_id from], name: issue_from_index)
      remove_index :issue_status_histories, name: issue_from_index
    end
  end
end
