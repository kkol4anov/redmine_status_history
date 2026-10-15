require File.expand_path('../test_helper', __dir__)

class IssueStateIntervalTest < ActiveSupport::TestCase
  fixtures :all

  setup do
    User.current = User.find(1)
    @issue = Issue.find(1)
    IssueStateInterval.delete_all
    @at = Time.utc(2026, 9, 30, 12)
  end

  test 'rebuild is idempotent and captures a real assignee-only save' do
    IssueStateInterval.rebuild!(@issue.id)
    before = IssueStateInterval.where(issue_id: @issue.id).order(:started_at, :event_id).last
    old_assignee = @issue.assigned_to_id
    new_assignee = old_assignee == 2 ? 3 : 2
    @issue.init_journal(User.current)
    @issue.assigned_to_id = new_assignee
    @issue.save!

    last = IssueStateInterval.where(issue_id: @issue.id).order(:started_at, :event_id).last
    assert_equal new_assignee, last.assigned_to_id
    assert_equal old_assignee, last.previous_assignee_id
    assert_not last.status_changed
    assert_equal last.started_at, before.reload.ended_at
    original = IssueStateInterval.where(issue_id: @issue.id).order(:started_at, :event_id).
      pluck(:event_id, :status_id, :assigned_to_id, :started_at, :ended_at)
    2.times { IssueStateInterval.rebuild!(@issue.id) }
    assert_equal original, IssueStateInterval.where(issue_id: @issue.id).order(:started_at, :event_id).
      pluck(:event_id, :status_id, :assigned_to_id, :started_at, :ended_at)
  end

  test 'interval hours are clipped to the requested period in SQL' do
    User.current.pref.time_zone = 'UTC'
    IssueStateInterval.create!(issue: @issue, event_id: 0, status_id: 2, assigned_to_id: 2,
                               started_at: @at, ended_at: @at + 2.days, status_started_at: @at)
    query = IssueStateQuery.new(name: '_', project: @issue.project)
    query.filters = { 'entry_kind' => { operator: '=', values: ['intervals'] },
                      'work_period' => { operator: '=', values: ['2026-10-01'] } }
    assert query.valid?, query.errors.full_messages.join(', ')
    assert_equal 1, query.base_scope.count
    assert_in_delta 24, query.total_for(:elapsed_hours), 0.001
    query.group_by = 'assigned_to'
    assert_in_delta 24, query.total_by_group_for(:elapsed_hours)[User.find(2)], 0.001
  end

  test 'one real save with both changes creates one interval' do
    IssueStateInterval.rebuild!(@issue.id)
    @issue.init_journal(User.current)
    @issue.status_id = @issue.status_id == 2 ? 1 : 2
    @issue.assigned_to_id = @issue.assigned_to_id == 2 ? 3 : 2
    assert_difference 'IssueStateInterval.where(issue_id: @issue.id).count', 1 do
      @issue.save!
    end
    row = IssueStateInterval.where(issue_id: @issue.id).order(:started_at, :event_id).last
    assert row.status_changed
    assert_equal @issue.status_id, row.status_id
    assert_equal @issue.assigned_to_id, row.assigned_to_id
  end

  test 'visible scope excludes private issues from unauthorized viewers' do
    @issue.update_column(:is_private, true)
    IssueStateInterval.seed!(@issue)
    assert_equal 0, IssueStateInterval.visible(User.anonymous).where(issue_id: @issue.id).count
  end

  test 'empty and reversed accounting periods are rejected' do
    query = IssueStateQuery.new(name: '_', project: @issue.project)
    query.add_filter('work_period', '!*', [''])
    assert_not query.valid?
    query.add_filter('work_period', '><', ['2026-10-03', '2026-10-01'])
    assert_not query.valid?
  end

  test 'issue history filters match the same interval' do
    IssueStateInterval.create!(issue: @issue, event_id: 0, status_id: 1, assigned_to_id: 2,
                               started_at: @at, ended_at: @at + 1.hour, status_started_at: @at)
    IssueStateInterval.create!(issue: @issue, event_id: 99999, status_id: 2, assigned_to_id: 3,
                               started_at: @at + 1.hour, status_started_at: @at + 1.hour)
    query = IssueQuery.new(name: '_', project: @issue.project)
    query.filters = {}
    query.add_filter('sh_assigned_to_id', '=', ['2'])
    query.add_filter('sh_work_status_id', '=', ['2'])
    assert_not_includes query.issues.map(&:id), @issue.id
    query.add_filter('sh_assigned_to_id', '=', ['3'])
    assert_includes query.issues.map(&:id), @issue.id
  end

  test 'initial states are not status transitions' do
    IssueStateInterval.seed!(@issue)
    query = IssueStateQuery.new(name: '_', project: @issue.project)
    query.filters = { 'entry_kind' => { operator: '=', values: ['transitions'] } }
    assert_equal 0, query.base_scope.count
  end
end
