class StatusLedgerController < ApplicationController
  menu_item :status_ledger
  before_action :find_project_by_project_id
  before_action :authorize
  helper :queries
  include QueriesHelper
  helper :custom_fields
  include CustomFieldsHelper

  def index
    # Native saved queries, but never reuse another user's query from the session.
    retrieve_query(IssueStateQuery, false)
    @entries = []
    unless @query.valid?
      if request.format.csv?
        render plain: @query.errors.full_messages.join('; '), status: :unprocessable_entity
      end
      return
    end

    @missing_count = @project.issues.visible.where.not(id: IssueStateInterval.select(:issue_id)).count
    scope = @query.results_scope
    if request.format.csv?
      limit = [[Setting.issues_export_limit.to_i, 1].max, 10000].min
      @entries = scope.limit(limit + 1).to_a
      if @entries.size > limit
        render plain: l(:error_sh_export_limit, limit: limit), status: :unprocessable_entity
        return
      end
      prepare_hours
      # Neutralize spreadsheet formulas in text cells without altering numeric values.
      columns = @query.inline_columns
      data = Redmine::Export::CSV.generate(encoding: 'UTF-8') do |csv|
        csv << columns.map(&:caption)
        @entries.each do |entry|
          csv << columns.map do |column|
            value = csv_content(column, entry).to_s
            value.match?(/\A[\s]*[=+@-]/) ? "'#{value}" : value
          end
        end
      end
      send_data data, type: 'text/csv; charset=utf-8', filename: 'status-history.csv'
    else
      @entry_count = @query.base_scope.count
      @entry_pages = Paginator.new(@entry_count, per_page_option, params[:page])
      @entries = scope.offset(@entry_pages.offset).limit(@entry_pages.per_page).to_a
      prepare_hours
      @saved_queries = IssueStateQuery.visible.where(project_id: [nil, @project.id]).order(:name)
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  private

  def prepare_hours
    @entries.each { |entry| entry.report_hours = entry[:calculated_hours].to_f }
  end
end
