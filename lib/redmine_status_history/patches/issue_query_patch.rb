module RedmineStatusHistory
  module Patches
    module IssueQueryPatch
      def self.included(base)
        base.prepend(InstanceMethods)
      end

      module InstanceMethods
        def initialize_available_filters
          super
          add_available_filter 'last_status_update', type: :date
          statuses = -> { issue_statuses_values }
          %w[sh_status_from sh_status_to sh_work_status_id].each do |field|
            add_available_filter field, type: :list, name: l("label_#{field}"), values: statuses
          end
          add_available_filter 'sh_changed_on', type: :date, name: l(:label_sh_changed_on)
          add_available_filter 'sh_work_period', type: :date, name: l(:label_sh_work_period)
          add_available_filter 'sh_assigned_to_id', type: :list_optional, name: l(:label_sh_executor),
                               values: -> { IssueStateQuery.new(project: project).principal_values }
          add_available_filter 'sh_hours', type: :float, name: l(:label_sh_interval_hours)
        end

        def validate_query_filters
          super
          %w[sh_changed_on sh_work_period].each do |field|
            next unless has_filter?(field)
            if operator_for(field) == '!*'
              errors.add(:base, l(:error_sh_period))
            elsif operator_for(field) == '><'
              left, right = values_for(field).map { |value| parse_date(value) }
              errors.add(:base, l(:error_sh_period)) if left && right && right.to_time < left.to_time
            end
          end
        end

        # One subquery for each family: all transition conditions refer to the same
        # transition; all work conditions refer to the same assignee interval.
        HISTORY_FILTERS = {
          'sh_status_from' => ['previous_status_id', :transitions],
          'sh_status_to' => ['status_id', :transitions],
          'sh_changed_on' => ['work_period', :transitions],
          'sh_assigned_to_id' => ['assigned_to_id', :intervals],
          'sh_work_status_id' => ['status_id', :intervals],
          'sh_work_period' => ['work_period', :intervals],
          'sh_hours' => ['elapsed_hours', :intervals]
        }.freeze

        HISTORY_FILTERS.each_key do |filter_name|
          define_method("sql_for_#{filter_name}_field") do |field, _operator, _values|
            kind = HISTORY_FILTERS.fetch(field)[1]
            selected = filters.keys.select { |key| HISTORY_FILTERS[key] && HISTORY_FILTERS[key][1] == kind }
            return '1=1' unless field == selected.first

            history_query = IssueStateQuery.new(name: '_')
            history_query.filters = { 'entry_kind' => { operator: '=', values: [kind.to_s] } }
            selected.each do |key|
              history_query.add_filter(HISTORY_FILTERS.fetch(key)[0], operator_for(key), values_for(key).dup)
            end
            if history_query.valid?
              # The subquery has its own visibility and permission scopes.
              scope = history_query.base_scope.select('issue_state_intervals.issue_id')
              "#{Issue.table_name}.id IN (#{scope.to_sql})"
            else
              '1=0'
            end
          end
        end

        def available_columns
          columns = super
          unless columns.any? { |column| column.name == :last_status_update }
            columns << QueryColumn.new(:last_status_update,
                                       sortable: "#{Issue.table_name}.last_status_update")
          end
          columns
        end
      end
    end
  end
end
