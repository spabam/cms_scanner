# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
# frozen_string_literal: true

# Tiny MCE
class Tinymce < Fingerprinter
  include GithubHosted

  def downloadable_versions
    github_releases('tinymce/tinymce')
  end
end
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
