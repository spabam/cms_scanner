# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
# frozen_string_literal: true

# Anchor CMS
class AnchorCms < Fingerprinter
  include GithubHosted
  include Experimental
  include IgnorePattern::PHP

  def downloadable_versions
    github_releases('anchorcms/anchor-cms')
  end
end
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
