# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
# frozen_string_literal: true

# Chamilo LMS
class ChamiloLms < Fingerprinter
  include GithubHosted
  include IgnorePattern::PHP

  def downloadable_versions
    github_releases('chamilo/chamilo-lms')
  end
end
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
