# Run without Rails: ruby plugins/redmine_status_history/test/timeline_standalone.rb
require_relative '../lib/redmine_status_history/timeline'

IssueSnapshot = Struct.new(:id, :status_id, :assigned_to_id, :author_id, :created_on)

def assert_equal(expected, actual)
  $timeline_assertions = ($timeline_assertions || 0) + 1
  raise "Expected #{expected.inspect}, got #{actual.inspect}" unless expected == actual
end

t0 = Time.utc(2026, 9, 30, 9)
issue = IssueSnapshot.new(42, 3, 8, 1, t0)
events = [
  { id: 11, at: t0 + 3600, author_id: 1, changes: { 'status_id' => ['1', '2'] } },
  { id: 12, at: t0 + 7200, author_id: 9, changes: { 'assigned_to_id' => ['7', '8'] } },
  { id: 13, at: t0 + 10800, author_id: 8, changes: { 'status_id' => ['2', '3'] } }
]
rows = RedmineStatusHistory::Timeline.build(issue, events)
assert_equal(4, rows.size)
assert_equal(7, rows.first[:assigned_to_id]) # recovered, not today's assignee
assert_equal(1, rows.first[:status_id])
assert_equal([false, true, false, true], rows.map { |r| r[:status_changed] })
assert_equal(7, rows[2][:previous_assignee_id])
assert_equal(8, rows[2][:assigned_to_id])
assert_equal(9, rows[2][:author_id]) # actor is not assignee
assert_equal(t0 + 3600, rows[3][:previous_status_started_at])
assert_equal(t0 + 7200, rows[1][:ended_at])
assert_equal(nil, rows.last[:ended_at])

combined = [{ id: 20, at: t0 + 100, author_id: 2,
              changes: { 'status_id' => ['1', '3'], 'assigned_to_id' => ['', '8'] } }]
rows = RedmineStatusHistory::Timeline.build(issue, combined)
assert_equal(2, rows.size) # atomic status + assignee event
assert_equal(nil, rows.first[:assigned_to_id])
assert_equal(8, rows.last[:assigned_to_id])

reentry = events + [
  { id: 14, at: t0 + 12000, author_id: 8, changes: { 'status_id' => ['3', '2'] } },
  { id: 15, at: t0 + 15000, author_id: 8, changes: { 'status_id' => ['2', '3'] } }
]
rows = RedmineStatusHistory::Timeline.build(issue, reentry)
assert_equal(t0 + 12000, rows.last[:previous_status_started_at])
assert_equal(6, rows.size)

no_change = events + [{ id: 16, at: t0 + 16000, author_id: 8, changes: { 'assigned_to_id' => ['8', '8'] } }]
assert_equal(4, RedmineStatusHistory::Timeline.build(issue, no_change).size)
assert_equal(1, RedmineStatusHistory::Timeline.build(issue, []).size)

# Two different journals at the same second retain their event ordering.
same_time = [events[0], events[1].merge(at: events[0][:at])]
rows = RedmineStatusHistory::Timeline.build(issue, same_time)
assert_equal(rows[1][:started_at], rows[1][:ended_at])
assert_equal(8, rows.last[:assigned_to_id])
puts "Timeline: #{$timeline_assertions} assertions passed"
