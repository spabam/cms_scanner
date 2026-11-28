# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
# frozen_string_literal: true

# Flatcore CMS
class FlatcoreCms < Fingerprinter
  include GithubHosted
  include Experimental
  include IgnorePattern::PHP

  def downloadable_versions
    github_releases('flatCore/flatCore-CMS')
  end
end
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
