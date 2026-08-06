module StatusHistoriesHelper
  def first_status(issue)
    issue.issue_status_histories.chronological.first&.status
  end

  def issue_status_changes(issue)
    issue.issue_status_histories.chronological.drop(1)
  end
end
