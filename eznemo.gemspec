$LOAD_PATH.unshift(File.expand_path('../lib', __FILE__))
require 'eznemo/version'


Gem::Specification.new do |s|
  s.name          = 'eznemo'
  s.version       = EzNemo::Version
  s.authors       = ['Ken J.']
  s.email         = ['kenjij@gmail.com']
  s.summary       = %q{Simple network monitoring}
  s.description   = %q{Simple network monitoring implemented with Ruby.}
  s.homepage      = 'https://github.com/kenjij/eznemo'
  s.license       = 'MIT'

  s.files         = `git ls-files`.split($/)
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.require_paths = ['lib']

  s.required_ruby_version = '>= 2.0.0'

  s.add_runtime_dependency 'kajiki', '~> 1.1'
  s.add_runtime_dependency 'eventmachine', '~> 1.0'
  s.add_runtime_dependency 'sequel', '~> 4.0'
end
