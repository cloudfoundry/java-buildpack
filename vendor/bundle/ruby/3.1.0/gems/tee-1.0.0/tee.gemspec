require File.expand_path('../lib/tee', __FILE__)

Gem::Specification.new do |s|
  s.name        = 'tee'
  s.version     = Tee::VERSION
  s.summary     = %q{A class like tee(1).}
  s.description = s.summary

  s.homepage    = 'https://github.com/m4i/tee'
  s.license     = 'MIT'
  s.author      = 'Masaki Takeuchi'
  s.email       = 'm.ishihara@gmail.com'

  s.files       = `git ls-files`.split($\)
  s.executables = s.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  s.test_files  = s.files.grep(%r{^(test|spec|features)/})

  s.required_ruby_version = '>= 1.9.2'

  s.add_development_dependency 'rake',  '~> 0.9.2.2'
  s.add_development_dependency 'rspec', '~> 2.11.0'
end
