# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
# frozen_string_literal: true

# Moodle
class Moodle < Fingerprinter
  include GithubHosted
  include IgnorePattern::PHP

  def downloadable_versions
    github_releases('moodle/moodle')
  end
end
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
