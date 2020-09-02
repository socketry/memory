
require_relative "lib/memory/version"

Gem::Specification.new do |spec|
	spec.name = "memory"
	spec.version = Memory::VERSION
	
	spec.summary = "Memory profiling routines for Ruby 2.3+"
	spec.authors = ["Samuel Williams", "Sam Saffron"]
	spec.license = "MIT"
	
	spec.homepage = "https://github.com/socketry/memory"
	
	spec.files = Dir.glob('{lib,bake}/**/*', File::FNM_DOTMATCH, base: __dir__)
	
	spec.required_ruby_version = ">= 2.3.0"
	
	spec.add_dependency "msgpack"
	
	spec.add_development_dependency "bundler"
	spec.add_development_dependency "covered"
	spec.add_development_dependency "rspec", "~> 3.0"
end
