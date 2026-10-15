require 'redmine_status_history/timeline'

class IssueStateInterval < ActiveRecord::Base
  belongs_to :issue
  has_one :project, through: :issue
  belongs_to :status, class_name: 'IssueStatus', optional: true
  belongs_to :previous_status, class_name: 'IssueStatus', optional: true
  belongs_to :assigned_to, class_name: 'Principal', optional: true
  belongs_to :previous_assignee, class_name: 'Principal', optional: true
  belongs_to :author, class_name: 'User', optional: true
  belongs_to :journal, foreign_key: :event_id, optional: true

  scope :visible, lambda { |user = User.current|
    joins(issue: :project).where(Issue.visible_condition(user)).
      where(Project.allowed_to_condition(user, :search_status_history))
  }

  attr_accessor :report_hours

  def elapsed_hours
    report_hours || ((ended_at || Time.current) - started_at) / 3600.0
  end

  def previous_status_hours
    return nil unless status_changed && previous_status_started_at
    (started_at - previous_status_started_at) / 3600.0
  end

  def self.seed!(issue)
    create!(issue_id: issue.id, event_id: 0, status_id: issue.status_id,
            assigned_to_id: issue.assigned_to_id, author_id: issue.author_id,
            started_at: issue.created_on, status_started_at: issue.created_on)
  end

  def self.events_for(issue)
    issue.journals.joins(:details).
      where(journal_details: { property: 'attr', prop_key: %w[status_id assigned_to_id] }).
      distinct.order(:created_on, :id).preload(:details).map do |journal|
      changes = journal.details.select { |d| d.property == 'attr' && RedmineStatusHistory::Timeline::FIELDS.include?(d.prop_key) }
      { id: journal.id, at: journal.created_on, author_id: journal.user_id,
        changes: changes.each_with_object({}) { |d, result| result[d.prop_key] = [d.old_value, d.value] } }
    end
  end

  # Offline/recovery path. The issue row lock is shared with the live writer;
  # replace one issue atomically, never erase the whole table before rebuilding.
  def self.rebuild!(issue_id)
    transaction do
      issue = Issue.lock.find(issue_id)
      rows = RedmineStatusHistory::Timeline.build(issue, events_for(issue))
      where(issue_id: issue.id).delete_all
      # Rails 5.2 has no insert_all. Use bounded, quoted multi-row inserts for
      # the derived rows instead of creating an AR object per historical event.
      columns = %i[issue_id event_id status_id assigned_to_id previous_status_id
                   previous_assignee_id author_id status_changed started_at ended_at
                   status_started_at previous_status_started_at]
      column_sql = columns.map { |name| connection.quote_column_name(name) }.join(', ')
      rows.each_slice(500) do |batch|
        values = batch.map do |attributes|
          '(' + columns.map { |name| connection.quote(attributes[name]) }.join(', ') + ')'
        end.join(', ')
        connection.execute("INSERT INTO #{quoted_table_name} (#{column_sql}) VALUES #{values}")
      end
    end
  end

  def self.record!(journal)
    transaction do
      issue = Issue.lock.find(journal.journalized_id)
      if exists?(issue_id: issue.id, event_id: journal.id)
        rebuild!(issue.id) if journal.saved_change_to_created_on?
        return
      end
      last = where(issue_id: issue.id).order(:started_at, :event_id).last
      # Existing installations are populated lazily until the explicit backfill.
      if last.nil? || journal.created_on < last.started_at
        rebuild!(issue.id)
        return
      end
      changes = journal.details.select { |d| d.property == 'attr' && RedmineStatusHistory::Timeline::FIELDS.include?(d.prop_key) }
      state = { 'status_id' => last.status_id, 'assigned_to_id' => last.assigned_to_id }
      changes.each { |d| state[d.prop_key] = RedmineStatusHistory::Timeline.identifier(d.value) }
      return if state['status_id'] == last.status_id && state['assigned_to_id'] == last.assigned_to_id

      changed = state['status_id'] != last.status_id
      last.update_columns(ended_at: journal.created_on)
      create!(issue_id: issue.id, event_id: journal.id, author_id: journal.user_id,
              status_id: state['status_id'], assigned_to_id: state['assigned_to_id'],
              previous_status_id: last.status_id, previous_assignee_id: last.assigned_to_id,
              status_changed: changed, started_at: journal.created_on,
              status_started_at: changed ? journal.created_on : last.status_started_at,
              previous_status_started_at: last.status_started_at)
    end
  end
end
