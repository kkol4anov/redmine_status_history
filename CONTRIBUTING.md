# Contributing

Bug reports and pull requests are welcome. Target the `main` branch, keep
changes focused and use Conventional Commits.

Run the tests from a supported Redmine checkout:

```sh
bundle exec rake redmine:plugins:migrate RAILS_ENV=test
bundle exec rake redmine:plugins:test NAME=redmine_status_history RAILS_ENV=test
```

Do not include credentials, personal data or customer data in issues or tests.
