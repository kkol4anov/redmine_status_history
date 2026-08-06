class PopulateLastStatusUpdateIssues < ActiveRecord::Migration[6.1]
  def up
    history_class = Class.new(ActiveRecord::Base) do
      self.table_name = 'issue_status_histories'
    end

    Issue.reset_column_information
    Issue.find_each do |issue|
      last_change = history_class.where(issue_id: issue.id).order(:from, :id).last
      issue.update_column(:last_status_update, last_change&.from || issue.updated_on)
    end
  end

  def down
    Issue.update_all(last_status_update: nil) if column_exists?(:issues, :last_status_update)
  end
end
