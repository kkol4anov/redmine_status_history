module RedmineStatusHistory
  module LedgerIssuePatch
    def self.included(base)
      base.has_many :issue_state_intervals, dependent: :delete_all
      base.after_create :initialize_state_intervals
    end

    def initialize_state_intervals
      IssueStateInterval.seed!(self)
    end
  end

  module LedgerJournalPatch
    def self.included(base)
      # after_save runs after the autosaved journal details, including private-note splitting.
      base.after_save :record_state_interval
      base.after_destroy :rebuild_state_intervals_after_journal_removal
    end

    def record_state_interval
      return unless journalized_type == 'Issue'
      return unless details.any? { |d| d.property == 'attr' && %w[status_id assigned_to_id].include?(d.prop_key) }

      IssueStateInterval.record!(self)
    end

    def rebuild_state_intervals_after_journal_removal
      return if destroyed_by_association || journalized_type != 'Issue'
      return unless IssueStateInterval.exists?(issue_id: journalized_id, event_id: id)
      return unless Issue.exists?(journalized_id)
      IssueStateInterval.rebuild!(journalized_id)
    end
  end

  module LedgerQueriesPatch
    private

    def redirect_to_issue_state_query(options)
      if @query.project
        redirect_to project_status_ledger_path(@query.project, options)
      else
        # Queries may be reusable across projects; choose the project on the next visit.
        redirect_to projects_path
      end
    end
  end
end
