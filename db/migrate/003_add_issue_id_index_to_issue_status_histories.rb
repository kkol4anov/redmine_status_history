class AddIssueIdIndexToIssueStatusHistories < ActiveRecord::Migration[5.2]
  def up
    add_index :issue_status_histories, :issue_id unless index_exists?(:issue_status_histories, :issue_id)
  end

  def down
    remove_index :issue_status_histories, :issue_id if index_exists?(:issue_status_histories, :issue_id)
  end
end
