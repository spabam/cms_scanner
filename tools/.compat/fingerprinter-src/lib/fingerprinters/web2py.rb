# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
# frozen_string_literal: true

# Web2py
class Web2py < Fingerprinter
  include GithubHosted
  include IgnorePattern::Python

  def downloadable_versions
    github_releases('web2py/web2py', %r{/(?:archive/refs/tags/(?:R-)?(?<v>[\d.]+)|download/(?:R-)?(?<v>[\d.]+)/[^\s]+)\.zip\z}i)
  end

  def extract_archive(archive_path, dest)
    super(archive_path, dest)

    rebase(File.join(dest, 'applications'), dest)
  end
end
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
