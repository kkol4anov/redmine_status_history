module RedmineStatusHistory
  module Patches
    module IssueQueryPatch
      def self.included(base)
        base.prepend(InstanceMethods)
      end

      module InstanceMethods
        def initialize_available_filters
          super
          add_available_filter 'last_status_update', type: :date unless available_filters.key?('last_status_update')
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
