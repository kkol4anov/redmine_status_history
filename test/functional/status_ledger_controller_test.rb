require File.expand_path('../test_helper', __dir__)

class StatusLedgerControllerTest < ActionController::TestCase
  fixtures :all

  setup do
    @project = Project.find(1)
    @request.session[:user_id] = 2
    Role.find(1).add_permission! :search_status_history
    IssueStateInterval.rebuild!(1)
  end

  test 'renders the native query UI' do
    get :index, params: { project_id: @project.identifier }
    assert_response :success
    assert_select 'form#query_form'
    assert_select '#filters-table'
  end

  test 'denies access without permission including csv' do
    Role.find(1).remove_permission! :search_status_history
    get :index, params: { project_id: @project.identifier, format: :csv }
    assert_response :forbidden
  end

  test 'cannot load another users private saved query' do
    query = IssueStateQuery.create!(name: 'Private', project: @project, user_id: 1,
                                    visibility: Query::VISIBILITY_PRIVATE)
    get :index, params: { project_id: @project.identifier, query_id: query.id }
    assert_response :forbidden
  end

  test 'exports selected columns' do
    get :index, params: { project_id: @project.identifier, format: :csv, set_filter: '1',
                         f: ['entry_kind'], op: { entry_kind: '=' }, v: { entry_kind: ['intervals'] },
                         c: ['issue', 'assigned_to', 'started_at'] }
    assert_response :success
    assert_match 'text/csv', response.content_type
  end
end
