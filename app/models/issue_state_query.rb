class IssueStateQuery < Query
  self.queried_class = IssueStateInterval
  self.view_permission = :search_status_history

  validate :validate_ledger_mode

  def initialize(attributes = nil, *args)
    super(attributes)
    self.filters ||= {
      'entry_kind' => { operator: '=', values: ['transitions'] },
      'work_period' => { operator: 'm', values: [''] }
    }
  end

  def initialize_available_filters
    add_available_filter 'entry_kind', type: :list, name: l(:label_sh_mode),
                         values: [[l(:label_sh_transitions), 'transitions'], [l(:label_sh_intervals), 'intervals']]
    add_available_filter 'work_period', type: :date, name: l(:label_sh_period)
    add_available_filter 'issue_id', type: :integer, name: l(:label_issue)
    add_available_filter 'issue.tracker_id', type: :list, name: l(:field_tracker),
                         values: -> { trackers.map { |t| [t.name, t.id.to_s] } }
    add_available_filter 'status_id', type: :list, name: l(:label_sh_status), values: -> { issue_statuses_values }
    add_available_filter 'previous_status_id', type: :list_optional, name: l(:label_sh_previous_status), values: -> { issue_statuses_values }
    %w[assigned_to_id previous_assignee_id author_id].each do |field|
      add_available_filter field, type: :list_optional, name: l("label_sh_#{field}"),
                           values: -> { principal_values }
    end
    add_available_filter 'elapsed_hours', type: :float, name: l(:label_sh_hours)
    add_available_filter 'ended_at', type: :date, name: l(:label_sh_end)
    add_custom_fields_filters(issue_custom_fields, :issue)
  end

  def principal_values
    # Includes inactive former members and groups; values are limited to projects
    # whose history the current user can read, rather than exposing all accounts.
    @principal_values ||= begin
      projects = Project.allowed_to(:search_status_history)
      projects = projects.where(id: project.self_and_descendants.select(:id)) if project
      ids = Member.where(project_id: projects.select(:id)).select(:user_id)
      history = IssueStateInterval.visible.where(issues: { project_id: projects.select(:id) })
      historical_ids = history.select('issue_state_intervals.assigned_to_id')
      author_ids = history.select('issue_state_intervals.author_id')
      Principal.where(id: ids).or(Principal.where(id: historical_ids)).or(Principal.where(id: author_ids)).
        order(:lastname, :firstname, :id).map { |p| [p.name, p.id.to_s] }
    end
  end

  def transitions?
    values_for('entry_kind') != ['intervals']
  end

  def available_columns
    return @available_columns if @available_columns
    table = IssueStateInterval.table_name
    @available_columns = [QueryColumn.new(:issue, sortable: 'issues.id', groupable: true, caption: :label_issue),
     QueryAssociationColumn.new(:issue, :subject, sortable: 'issues.subject', caption: :field_subject),
     QueryAssociationColumn.new(:issue, :tracker, sortable: 'issues.tracker_id', caption: :field_tracker),
     QueryAssociationColumn.new(:issue, :project, sortable: 'projects.name', caption: :field_project),
     QueryColumn.new(:started_at, sortable: "#{table}.started_at", caption: :label_sh_start),
     QueryColumn.new(:ended_at, sortable: "#{table}.ended_at", caption: :label_sh_end),
     QueryColumn.new(:previous_status, caption: :label_sh_previous_status),
     QueryColumn.new(:status, sortable: "#{table}.status_id", groupable: "#{table}.status_id", caption: :label_sh_status),
     QueryColumn.new(:author, sortable: "#{table}.author_id", groupable: "#{table}.author_id", caption: :field_author),
     QueryColumn.new(:previous_assignee, caption: :label_sh_previous_assignee_id),
     QueryColumn.new(:assigned_to, sortable: "#{table}.assigned_to_id", groupable: "#{table}.assigned_to_id", caption: :label_sh_assigned_to_id),
     QueryColumn.new(:previous_status_hours, caption: :label_sh_previous_hours),
     QueryColumn.new(:elapsed_hours, sortable: duration_sql, totalable: !transitions?, caption: :label_sh_hours)] +
      issue_custom_fields.visible.map { |cf| QueryAssociationCustomFieldColumn.new(:issue, cf, totalable: false) }
  end

  def build_from_params(params, defaults = {})
    @available_columns = nil
    super
  end

  def default_columns_names
    if transitions?
      %i[issue issue.subject started_at previous_status status author previous_assignee assigned_to previous_status_hours]
    else
      %i[issue issue.subject started_at ended_at status assigned_to elapsed_hours]
    end
  end

  def default_sort_criteria
    [['started_at', 'desc']]
  end

  def default_totalable_names
    transitions? ? [] : [:elapsed_hours]
  end

  def base_scope
    IssueStateInterval.visible.where(statement)
  end

  def results_scope
    ordering = [group_by_sort_order, sort_clause, 'issue_state_intervals.id DESC'].flatten.reject(&:blank?)
    base_scope.select('issue_state_intervals.*', "#{duration_sql} AS calculated_hours").order(ordering).
      preload(:status, :previous_status, :author, :assigned_to, :previous_assignee,
              issue: [:project, :tracker, { custom_values: :custom_field }])
  end

  def total_for_elapsed_hours(scope)
    map_total(scope.sum(duration_sql)) { |value| value.to_f.round(2) }
  end

  def sql_for_entry_kind_field(_field, _operator, _value)
    transitions? ? 'issue_state_intervals.status_changed = TRUE' : '1=1'
  end

  def sql_for_issue_tracker_id_field(field, operator, value)
    sql_for_field(field, operator, value, 'issues', 'tracker_id')
  end

  def sql_for_elapsed_hours_field(field, operator, value)
    # Query expects table.column; use a safe placeholder then replace the entire expression.
    sql_for_field(field, operator, value, 'sh_value', 'hours').gsub('sh_value.hours', "(#{duration_sql})")
  end

  def sql_for_work_period_field(field, operator, value)
    return '1=1' if operator == '*'
    sql_for_field(field, operator, value, 'issue_state_intervals', 'work_period')
  end

  def period_bounds
    @period_bounds = [nil, nil]
    if has_filter?('work_period') && operator_for('work_period') != '*'
      sql_for_work_period_field('work_period', operator_for('work_period'), values_for('work_period'))
    end
    @period_bounds
  end

  def report_time
    @report_time ||= Time.current
  end

  def duration_sql
    from, to = period_bounds
    quote = self.class.connection.method(:quote)
    start_sql = 'issue_state_intervals.started_at'
    end_sql = "COALESCE(issue_state_intervals.ended_at, #{quote.call(report_time)})"
    start_sql = "GREATEST(#{start_sql}, #{quote.call(from)})" if from
    end_sql = "LEAST(#{end_sql}, #{quote.call(to)})" if to
    "GREATEST(0, TIMESTAMPDIFF(SECOND, #{start_sql}, #{end_sql})) / 3600.0"
  end

  def date_clause(table, field, from, to, is_custom_filter)
    return super unless field == 'work_period'

    lower = from.is_a?(Date) ? date_for_user_time_zone(from.year, from.month, from.day) : from
    upper = to.is_a?(Date) ? date_for_user_time_zone(to.year, to.month, to.day).advance(days: 1) : to
    @period_bounds = [lower, upper]
    quote = self.class.connection.method(:quote)
    clauses = []
    if transitions?
      clauses << "#{table}.started_at >= #{quote.call(lower)}" if lower
    else
      clauses << "COALESCE(#{table}.ended_at, #{quote.call(report_time)}) > #{quote.call(lower)}" if lower
      clauses << "#{table}.started_at < COALESCE(#{table}.ended_at, #{quote.call(report_time)})"
    end
    clauses << "#{table}.started_at < #{quote.call(upper)}" if upper
    clauses.empty? ? '1=1' : clauses.join(' AND ')
  end

  def validate_ledger_mode
    unless operator_for('entry_kind') == '=' && [%w[transitions], %w[intervals]].include?(values_for('entry_kind'))
      errors.add(:base, l(:error_sh_mode))
    end
    if has_filter?('work_period') && operator_for('work_period') == '!*'
      errors.add(:base, l(:error_sh_period))
    end
    if has_filter?('work_period') && operator_for('work_period') == '><'
      left, right = values_for('work_period').map { |v| parse_date(v) }
      errors.add(:base, l(:error_sh_period)) if left && right && right.to_time < left.to_time
    end
  end
end
