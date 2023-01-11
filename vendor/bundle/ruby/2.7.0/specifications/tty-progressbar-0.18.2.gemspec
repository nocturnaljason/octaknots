# -*- encoding: utf-8 -*-
# stub: tty-progressbar 0.18.2 ruby lib

Gem::Specification.new do |s|
  s.name = "tty-progressbar".freeze
  s.version = "0.18.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "allowed_push_host" => "https://rubygems.org", "bug_tracker_uri" => "https://github.com/piotrmurach/tty-progressbar/issues", "changelog_uri" => "https://github.com/piotrmurach/tty-progressbar/blob/master/CHANGELOG.md", "documentation_uri" => "https://www.rubydoc.info/gems/tty-progressbar", "homepage_uri" => "https://ttytoolkit.org", "source_code_uri" => "https://github.com/piotrmurach/tty-progressbar" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Piotr Murach".freeze]
  s.date = "2021-03-08"
  s.description = "Display a single or multiple progress bars in the terminal. A progress bar can show determinate or indeterminate progress that can be paused and resumed at any time. A bar format supports many tokens for common information display like elapsed time, estimated time to completion, mean rate and more.".freeze
  s.email = ["piotr@piotrmurach.com".freeze]
  s.extra_rdoc_files = ["README.md".freeze, "CHANGELOG.md".freeze, "LICENSE.txt".freeze]
  s.files = ["CHANGELOG.md".freeze, "LICENSE.txt".freeze, "README.md".freeze]
  s.homepage = "https://ttytoolkit.org".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.0.0".freeze)
  s.rubygems_version = "3.1.2".freeze
  s.summary = "A flexible and extensible progress bar for terminal applications.".freeze

  s.installed_by_version = "3.1.2" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_runtime_dependency(%q<strings-ansi>.freeze, ["~> 0.2"])
    s.add_runtime_dependency(%q<tty-cursor>.freeze, ["~> 0.7"])
    s.add_runtime_dependency(%q<tty-screen>.freeze, ["~> 0.8"])
    s.add_runtime_dependency(%q<unicode-display_width>.freeze, [">= 1.6", "< 3.0"])
    s.add_development_dependency(%q<rake>.freeze, [">= 0"])
    s.add_development_dependency(%q<rspec>.freeze, [">= 3.0"])
    s.add_development_dependency(%q<timecop>.freeze, ["~> 0.9"])
  else
    s.add_dependency(%q<strings-ansi>.freeze, ["~> 0.2"])
    s.add_dependency(%q<tty-cursor>.freeze, ["~> 0.7"])
    s.add_dependency(%q<tty-screen>.freeze, ["~> 0.8"])
    s.add_dependency(%q<unicode-display_width>.freeze, [">= 1.6", "< 3.0"])
    s.add_dependency(%q<rake>.freeze, [">= 0"])
    s.add_dependency(%q<rspec>.freeze, [">= 3.0"])
    s.add_dependency(%q<timecop>.freeze, ["~> 0.9"])
  end
end
