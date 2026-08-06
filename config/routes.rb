Rails.application.routes.draw do
  match 'projects/:project_id/issue_status_history/search',
        to: 'status_histories#search', via: %i[get post], as: 'search_status_history'
  get 'projects/:project_id/issue_status_history/:issue_id',
      to: 'status_histories#show_history', as: 'show_status_history'
end
