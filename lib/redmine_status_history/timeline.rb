module RedmineStatusHistory
  # Pure timeline reconstruction. Uses old_value to recover the initial assignee,
  # then replays each journal atomically. No current-user attribution is used.
  module Timeline
    FIELDS = %w[status_id assigned_to_id].freeze

    def self.identifier(value)
      value.nil? || value.to_s.empty? ? nil : value.to_i
    end

    def self.build(issue, events)
      state = { 'status_id' => issue.status_id, 'assigned_to_id' => issue.assigned_to_id }
      FIELDS.each do |field|
        first = events.find { |event| event[:changes].key?(field) }
        state[field] = identifier(first[:changes][field][0]) if first
      end
      rows = [{ issue_id: issue.id, event_id: 0, status_id: state['status_id'],
                assigned_to_id: state['assigned_to_id'], author_id: issue.author_id,
                status_changed: false, started_at: issue.created_on,
                status_started_at: issue.created_on }]
      events.each do |event|
        changes = event[:changes]
        before = state.dup
        changes.each { |field, values| state[field] = identifier(values[1]) }
        next if before == state

        previous = rows.last
        changed = before['status_id'] != state['status_id']
        previous[:ended_at] = event[:at]
        rows << { issue_id: issue.id, event_id: event[:id], author_id: event[:author_id],
                  status_id: state['status_id'], assigned_to_id: state['assigned_to_id'],
                  previous_status_id: before['status_id'], previous_assignee_id: before['assigned_to_id'],
                  status_changed: changed, started_at: event[:at],
                  status_started_at: changed ? event[:at] : previous[:status_started_at],
                  previous_status_started_at: previous[:status_started_at] }
      end
      rows
    end
  end
end
