# Redmine Status History


`redmine_status_history` records every issue status interval and provides a
project-level search for transitions between statuses and dates. It also adds
the last status-change date as an issue query filter and column.

## Features

- Search status transitions within a project and date range.
- Optionally filter by both the previous and destination statuses.
- View the complete status timeline for an issue.
- Filter and sort issue queries by the last status-change date.
- Restrict access with a project permission.

## Redmine 4.2 compatibility backport

This local backport targets Redmine 4.2.9, Rails 5.2.8.1, Ruby 2.7.4-p191
and MariaDB 10.5.18 with the mysql2 adapter. It adds no
runtime gems. The target stack has not been executed in the patch author's
environment; the upstream CI results below do not certify this backport.
Version of the plugin was downgraded to 1.0.0. It will be maintained independent of upstream.

## Upstream compatibility (before this backport)

| Plugin | Redmine | Rails |
| --- | --- | --- |
| 2.0.x | 5.0.x, 5.1.x | 6.1 |
| 2.0.x | 6.0.x, 6.1.x | 7.2 |

The CI matrix covers Redmine 5.0.14, 5.1.13, 6.0.10 and 6.1.3. Redmine 5.x
is supported by this plugin even though it is no longer maintained upstream.

## Compatibility after this backport

| Plugin | Redmine | Rails | Ruby | MariaDB |
| --- | --- | --- | --- | --- |
| 1.x.x | 4.2.9 | 5.2.8.1 | 2.7.4-p191 | 10.5.18 |

## Installation

From the Redmine directory:

```sh
cd plugins
git clone https://github.com/redmineservices/redmine_status_history.git
cd ..
bundle exec rake redmine:plugins:migrate NAME=redmine_status_history RAILS_ENV=production
```

Restart Redmine and grant **Search issue status history** to the appropriate
project roles. The first migration reconstructs existing status history and
can take time on installations with many issues.

## Upgrade from 1.x

Back up the database, replace the plugin files and run the migration command
shown above. Restart Redmine after the migration.

## Usage

Open a project's issue list and select **Search issue changes**. Choose the
destination status, optional previous status and date range. The result list
links to the complete status timeline for each matching issue.

The standard issue query builder also exposes **Last status change** as a date
filter and sortable column.

## Uninstallation

Back up the database, then run:

```sh
bundle exec rake redmine:plugins:migrate NAME=redmine_status_history VERSION=0 RAILS_ENV=production
```

Remove the plugin directory and restart Redmine.

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md). Please report security issues according
to [SECURITY.md](SECURITY.md).

## License

This project is licensed under the GNU General Public License v2.0 or later.
See [LICENSE](LICENSE).
