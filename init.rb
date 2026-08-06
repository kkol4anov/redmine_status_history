require 'redmine'

plugin_lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(plugin_lib) unless $LOAD_PATH.include?(plugin_lib)

require 'redmine_status_history/patches/issue_patch'
require 'redmine_status_history/patches/issue_query_patch'
require 'redmine_status_history/patches/journal_detail_patch'

unless Issue.include?(RedmineStatusHistory::Patches::IssuePatch)
  Issue.include(RedmineStatusHistory::Patches::IssuePatch)
end
unless IssueQuery.include?(RedmineStatusHistory::Patches::IssueQueryPatch)
  IssueQuery.include(RedmineStatusHistory::Patches::IssueQueryPatch)
end
unless JournalDetail.include?(RedmineStatusHistory::Patches::JournalDetailPatch)
  JournalDetail.include(RedmineStatusHistory::Patches::JournalDetailPatch)
end

require 'redmine_status_history/hooks/view_issues_index_bottom'

Redmine::Plugin.register :redmine_status_history do
  name 'Redmine Status History'
  author 'Redmine Services'
  description 'Searches, displays and filters issue status change history'
  version '2.0.0'
  url 'https://github.com/redmineservices/redmine_status_history'
  author_url 'https://github.com/redmineservices'
  requires_redmine version_or_higher: '5.0.0'

  project_module :issue_tracking do
    permission :search_status_history,
               { status_histories: %i[search show_history] },
               require: :member
  end
end
