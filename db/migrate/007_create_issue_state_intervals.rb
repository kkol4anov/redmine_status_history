class CreateIssueStateIntervals < ActiveRecord::Migration[5.2]
  def up
    create_table :issue_state_intervals do |t|
      t.integer :issue_id, null: false
      # 0 identifies the initial state; real events use the Redmine journal ID.
      t.integer :event_id, null: false, default: 0
      t.integer :status_id
      t.integer :assigned_to_id
      t.integer :previous_status_id
      t.integer :previous_assignee_id
      t.integer :author_id
      t.boolean :status_changed, null: false, default: false
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.datetime :status_started_at, null: false
      t.datetime :previous_status_started_at
    end
    add_index :issue_state_intervals, [:issue_id, :event_id], unique: true, name: 'isi_issue_event'
    add_index :issue_state_intervals, [:issue_id, :started_at], name: 'isi_issue_start'
    add_index :issue_state_intervals, [:status_changed, :started_at], name: 'isi_transition_start'
    add_index :issue_state_intervals, [:assigned_to_id, :status_id, :started_at], name: 'isi_assignee_status_start'
  end

  def down
    # Remove only queries of this plugin's new STI type; ordinary issue/time
    # queries and the pre-existing status history are not touched.
    execute "DELETE FROM queries_roles WHERE query_id IN (SELECT id FROM queries WHERE type = 'IssueStateQuery')"
    execute "DELETE FROM queries WHERE type = 'IssueStateQuery'"
    drop_table :issue_state_intervals
  end
end
