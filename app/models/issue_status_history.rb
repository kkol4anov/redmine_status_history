class IssueStatusHistory < (defined?(ApplicationRecord) ? ApplicationRecord : ActiveRecord::Base)
  belongs_to :status, class_name: 'IssueStatus'
  belongs_to :previous_status, class_name: 'IssueStatus', optional: true
  belongs_to :user
  belongs_to :journal, optional: true
  belongs_to :issue

  after_create :update_last_status_update

  scope :chronological, -> { order(:from, :id) }

  def self.search_changes(project, status_id, date_from, previous_status_id = nil, date_to = nil,
                          user = User.current)
    start_at = date_from.in_time_zone.beginning_of_day
    end_at = (date_to || Time.zone.today).in_time_zone.end_of_day
    conditions = {
      from: start_at..end_at
    }

    conditions[:status_id] = status_id if status_id.present?

    conditions[:previous_status_id] = previous_status_id if previous_status_id.present?

    Issue
      .where(project_id: project.id)
      .visible(user)
      .joins(:issue_status_histories)
      .where({ issue_status_histories: conditions })
      .distinct
  end

  def update_last_status_update
    return unless issue && from
    return if issue.last_status_update && issue.last_status_update > from

    issue.update_column(:last_status_update, from)
  end

  def lifetime
    (to || Time.current) - from
  end

  def lifetime_in_minutes
    lifetime / 60.0
  end
end
