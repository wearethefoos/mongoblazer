# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'mongoblazer/version'

Gem::Specification.new do |spec|
  spec.name          = "mongoblazer"
  spec.version       = Mongoblazer::VERSION
  spec.authors       = ["Wouter de Vos"]
  spec.email         = ["wouter@surecreations.com"]
  spec.description   = %q{MongoBlazer to flatten relational data from ActiveRecord Models into Mongodb Documents}
  spec.summary       = %q{MongoBlazer to flatten ActiveRecord Models into Mongodb Documents}
  spec.homepage      = "http://springest.github.com/mongoblazer"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "database_cleaner"
  spec.add_development_dependency "debugger"
  spec.add_development_dependency "sqlite3"

  spec.add_runtime_dependency "rails"
  spec.add_runtime_dependency "mongoid"
end
