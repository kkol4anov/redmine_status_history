require 'redmine'

plugin_lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(plugin_lib) unless $LOAD_PATH.include?(plugin_lib)

require 'redmine_status_history/patches/issue_patch'
require 'redmine_status_history/patches/issue_query_patch'
require 'redmine_status_history/patches/journal_detail_patch'
require 'redmine_status_history/patches/ledger_patch'

# Rails 5.2 uses the classic autoloader. Apply patches after initialization
# and again when reloadable Redmine model classes are replaced.
Rails.configuration.to_prepare do
  require_dependency 'issue'
  require_dependency 'issue_query'
  require_dependency 'journal_detail'
  require_dependency 'journal'
  require_dependency 'queries_controller'

  {
    Issue => RedmineStatusHistory::Patches::IssuePatch,
    IssueQuery => RedmineStatusHistory::Patches::IssueQueryPatch,
    JournalDetail => RedmineStatusHistory::Patches::JournalDetailPatch
  }.each do |model, patch|
    model.send(:include, patch) unless model.include?(patch)
  end
  Issue.include RedmineStatusHistory::LedgerIssuePatch unless Issue.include?(RedmineStatusHistory::LedgerIssuePatch)
  Journal.include RedmineStatusHistory::LedgerJournalPatch unless Journal.include?(RedmineStatusHistory::LedgerJournalPatch)
  QueriesController.include RedmineStatusHistory::LedgerQueriesPatch unless QueriesController.include?(RedmineStatusHistory::LedgerQueriesPatch)
end

require 'redmine_status_history/hooks/view_issues_index_bottom'

Redmine::Plugin.register :redmine_status_history do
  name 'Redmine Status History'
  author 'Redmine Services / Konstantin Kolchanov'
  description 'Searches, displays and filters issue status change history'
  version '1.1.0.rc1'
  url 'https://github.com/kkol4anov/redmine_status_history'
  author_url 'https://github.com/redmineservices'
  requires_redmine version_or_higher: '4.2.9'

  project_module :issue_tracking do
    permission :search_status_history,
               { status_histories: %i[search show_history], status_ledger: [:index] },
               require: :member
  end
  menu :project_menu, :status_ledger, { controller: 'status_ledger', action: 'index' },
       caption: :label_status_ledger, param: :project_id, after: :issues
end
