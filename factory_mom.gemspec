# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'factory_mom/version'

Gem::Specification.new do |spec|
  spec.name          = 'factory_mom'
  spec.version       = FactoryMom::VERSION
  spec.authors       = ['Aleksei Matiushkin']
  spec.email         = ['aleksei.matiushkin@kantox.com']

  spec.summary       = 'MetaFactory for FactoryGirl to produce factories.'
  spec.description   = %q{FactoryMom is the factory generator, bases on database structure analysis.}
  spec.homepage      = 'http://github.com/am-kantox/factory_mom'
  spec.license       = 'MIT'

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  if spec.respond_to?(:metadata)
    # spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise 'RubyGems 2.0 or newer is required to protect against public gem pushes.'
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'bin'
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.10'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'pry', '~> 0.10'
  spec.add_development_dependency 'sqlite3'
  spec.add_development_dependency 'rspec'

  spec.add_dependency 'factory_girl_rails', '~> 4'
  spec.add_dependency 'activerecord', '~> 3'
  spec.add_dependency 'foreigner' # FIXME FOR RAILS3 ONLY?
end
