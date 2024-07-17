# -*- encoding: utf-8 -*-
# stub: tee 1.0.0 ruby lib

Gem::Specification.new do |s|
  s.name = "tee".freeze
  s.version = "1.0.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Masaki Takeuchi".freeze]
  s.date = "2012-08-21"
  s.description = "A class like tee(1).".freeze
  s.email = "m.ishihara@gmail.com".freeze
  s.homepage = "https://github.com/m4i/tee".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.2".freeze)
  s.rubygems_version = "3.3.27".freeze
  s.summary = "A class like tee(1).".freeze

  s.installed_by_version = "3.3.27" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 3
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_development_dependency(%q<rake>.freeze, ["~> 0.9.2.2"])
    s.add_development_dependency(%q<rspec>.freeze, ["~> 2.11.0"])
  else
    s.add_dependency(%q<rake>.freeze, ["~> 0.9.2.2"])
    s.add_dependency(%q<rspec>.freeze, ["~> 2.11.0"])
  end
end
