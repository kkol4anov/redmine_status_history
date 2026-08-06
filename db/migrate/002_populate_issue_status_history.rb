class PopulateIssueStatusHistory < ActiveRecord::Migration[6.1]
  def up
    history_class = Class.new(ActiveRecord::Base) do
      self.table_name = 'issue_status_histories'
    end

    Issue.find_each do |issue|
      changes = issue.journals.includes(:details).flat_map do |journal|
        journal.details.select { |detail| detail.property == 'attr' && detail.prop_key == 'status_id' }
      end.sort_by { |detail| [detail.journal.created_on || Time.at(0), detail.id] }

      if changes.any?
        first_change = changes.first
        last_change = history_class.create!(
          from: issue.created_on,
          to: first_change.journal.created_on,
          status_id: first_change.old_value.presence || issue.status_id,
          user_id: issue.author_id,
          issue_id: issue.id
        )

        changes.each do |change|
          changed_at = change.journal.created_on
          last_change.update_columns(to: changed_at) unless last_change.to == changed_at
          last_change = history_class.create!(
            from: changed_at,
            status_id: change.value,
            user_id: change.journal.user_id,
            journal_id: change.journal_id,
            previous_status_id: change.old_value,
            issue_id: issue.id
          )
        end
      else
        history_class.create!(
          from: issue.created_on,
          status_id: issue.status_id,
          user_id: issue.author_id,
          issue_id: issue.id
        )
      end
    end
  end

  def down
    execute 'DELETE FROM issue_status_histories' if table_exists?(:issue_status_histories)
  end
end
