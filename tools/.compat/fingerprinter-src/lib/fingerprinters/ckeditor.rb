# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
# frozen_string_literal: true

# CKEditor
class Ckeditor < Fingerprinter
  include GithubHosted

  def downloadable_versions
    github_releases('ckeditor/ckeditor4-releases')
  end
end
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
