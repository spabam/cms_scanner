# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
# frozen_string_literal: true

# Mantis Bug Tracker
class Mantisbt < Fingerprinter
  include GithubHosted
  include Experimental
  include IgnorePattern::PHP

  def downloadable_versions
    github_releases('mantisbt/mantisbt', /release-(?<v>[0-9\.]+)\.zip\z/i)
  end
end
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
