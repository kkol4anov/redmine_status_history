require 'redmine'

plugin_lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(plugin_lib) unless $LOAD_PATH.include?(plugin_lib)

require 'redmine_status_history/patches/issue_patch'
require 'redmine_status_history/patches/issue_query_patch'
require 'redmine_status_history/patches/journal_detail_patch'

# Rails 5.2 uses the classic autoloader. Apply patches after initialization
# and again when reloadable Redmine model classes are replaced.
Rails.configuration.to_prepare do
  require_dependency 'issue'
  require_dependency 'issue_query'
  require_dependency 'journal_detail'

  {
    Issue => RedmineStatusHistory::Patches::IssuePatch,
    IssueQuery => RedmineStatusHistory::Patches::IssueQueryPatch,
    JournalDetail => RedmineStatusHistory::Patches::JournalDetailPatch
  }.each do |model, patch|
    model.send(:include, patch) unless model.include?(patch)
  end
end

require 'redmine_status_history/hooks/view_issues_index_bottom'

Redmine::Plugin.register :redmine_status_history do
  name 'Redmine Status History'
  author 'Redmine Services / Konstantin Kolchanov'
  description 'Searches, displays and filters issue status change history'
  version '1.0.0.rc1'
  url 'https://github.com/kkol4anov/redmine_status_history'
  author_url 'https://github.com/redmineservices'
  requires_redmine version_or_higher: '4.2.9'

  project_module :issue_tracking do
    permission :search_status_history,
               { status_histories: %i[search show_history] },
               require: :member
  end
end
