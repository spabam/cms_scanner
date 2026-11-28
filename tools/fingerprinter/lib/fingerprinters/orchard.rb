# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
# frozen_string_literal: true

# Orchard CMS
class Orchard < Fingerprinter
  include GithubHosted
  include IgnorePattern::ASP

  def downloadable_versions
    github_releases('OrchardCMS/Orchard')
  end

  def extract_archive(archive_path, dest)
    super(archive_path, dest)

    rebase(File.join(dest, 'src', 'Orchard.Web'), dest)
  end
end
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
