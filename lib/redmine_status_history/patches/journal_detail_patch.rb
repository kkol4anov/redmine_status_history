module RedmineStatusHistory
  module Patches
    module JournalDetailPatch
      def self.included(base) # :nodoc:
        base.send(:include, InstanceMethods)
        base.class_eval do
          after_create :create_history
        end
      end

      module InstanceMethods
        def create_history
          return unless property == 'attr' && prop_key == 'status_id'
          return unless journal&.journalized.is_a?(Issue)
          return if IssueStatusHistory.exists?(journal_id: journal_id)

          issue = journal.journalized
          changed_at = journal.created_on || Time.current

          IssueStatusHistory.transaction do
            last_change = issue.issue_status_histories.chronological.last
            IssueStatusHistory.create!(
              from: changed_at,
              status_id: value,
              user_id: journal.user_id,
              journal_id: journal_id,
              previous_status_id: old_value,
              issue_id: issue.id
            )
            last_change&.update!(to: changed_at)
          end
        end
      end
    end
  end
end
