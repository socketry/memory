# frozen_string_literal: true

require_relative "lib/memory/version"

Gem::Specification.new do |spec|
	spec.name = "memory"
	spec.version = Memory::VERSION
	
	spec.summary = "Memory profiling routines for Ruby 2.3+"
	spec.authors = ["Sam Saffron", "Dave Gynn", "Nick LaMuro", "Jonas Peschla", "Samuel Williams", "Ashwin Maroli", "Søren Skovsbøll", "Richard Schneeman", "Anton Davydov", "Benoit Tigeot", "Jean Boussier", "Vincent Woo", "Andrew Grimm", "Boris Staal", "Danny Ben Shitrit", "Espartaco Palma", "Florian Schwab", "Hamdi Akoğuz", "Jaiden Mispy", "John Bachir", "Luís Ferreira", "Mike Subelsky", "Olle Jonsson", "Vasily Kolesnikov", "William Tabi"]
	spec.license = "MIT"
	
	spec.cert_chain  = ['release.cert']
	spec.signing_key = File.expand_path('~/.gem/release.pem')
	
	spec.homepage = "https://github.com/socketry/memory"
	
	spec.files = Dir.glob(['{bake,lib}/**/*', '*.md'], File::FNM_DOTMATCH, base: __dir__)
	
	spec.required_ruby_version = ">= 2.3.0"
	
	spec.add_dependency "bake", "~> 0.15"
	spec.add_dependency "console"
	spec.add_dependency "msgpack"
	
	spec.add_development_dependency "bake-test"
	spec.add_development_dependency "bundler"
	spec.add_development_dependency "covered"
	spec.add_development_dependency "sus"
end
