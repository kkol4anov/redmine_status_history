namespace :redmine_status_history do
  desc 'Rebuild status/assignee intervals (FROM_ID, TO_ID, BATCH_SIZE; resume by issue ID)'
  task rebuild_intervals: :environment do
    scope = Issue.order(:id)
    scope = scope.where('id >= ?', Integer(ENV['FROM_ID'])) if ENV['FROM_ID'].present?
    scope = scope.where('id <= ?', Integer(ENV['TO_ID'])) if ENV['TO_ID'].present?
    batch = [[Integer(ENV.fetch('BATCH_SIZE', '100')), 1].max, 1000].min
    scope.find_each(batch_size: batch) do |issue|
      IssueStateInterval.rebuild!(issue.id)
      puts "Rebuilt issue ##{issue.id}"
    end
  end
end
