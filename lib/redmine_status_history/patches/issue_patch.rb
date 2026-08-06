module RedmineStatusHistory
  module Patches
    module IssuePatch
      def self.included(base)
        base.send(:include, InstanceMethods)
        base.class_eval do
          has_many :issue_status_histories, -> { order(:from, :id) }, dependent: :delete_all

          before_create :set_default_last_status_update
          after_create :create_status_history
        end
      end

      module InstanceMethods
        def create_status_history
          status_history = {
            from: created_on || Time.current,
            status_id: status_id,
            user_id: author_id,
            issue_id: id
          }
          IssueStatusHistory.create!(status_history)
        end

        def set_default_last_status_update
          self.last_status_update = Time.current
        end
      end
    end
  end
end
