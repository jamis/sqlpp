lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "sqlpp/version"

Gem::Specification.new do |gem|
  gem.version     = SQLPP::Version::STRING
  gem.name        = "sqlpp"
  gem.authors     = ["Jamis Buck"]
  gem.email       = ["jamis@jamisbuck.org"]
  gem.homepage    = "http://github.com/jamis/sqlpp"
  gem.summary     = "A simplistic SQL parser and pretty-printer"
  gem.description = "A simplistic SQL parser and pretty-printer"
  gem.license     = 'MIT'

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^test/})
  gem.require_paths = ["lib"]

  ##
  # Development dependencies
  #
  gem.add_development_dependency "rake"
  gem.add_development_dependency "minitest"
end
