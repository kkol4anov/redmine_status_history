class AddLastStatusUpdateToIssues < ActiveRecord::Migration[5.2]
  def up
    add_column :issues, :last_status_update, :datetime unless column_exists?(:issues, :last_status_update)
  end

  def down
    remove_column :issues, :last_status_update if column_exists?(:issues, :last_status_update)
  end
end
