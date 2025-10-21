# frozen_string_literal: true

require_relative "lib/memory/version"

Gem::Specification.new do |spec|
	spec.name = "memory"
	spec.version = Memory::VERSION
	
	spec.summary = "Memory profiling routines for Ruby 2.3+"
	spec.authors = ["Sam Saffron", "Dave Gynn", "Samuel Williams", "Nick LaMuro", "Jonas Peschla", "Ashwin Maroli", "Søren Skovsbøll", "Richard Schneeman", "Anton Davydov", "Benoit Tigeot", "Jean Boussier", "Vincent Woo", "Andrew Grimm", "Boris Staal", "Danny Ben Shitrit", "Espartaco Palma", "Florian Schwab", "Hamdi Akoğuz", "Jaiden Mispy", "John Bachir", "Luís Ferreira", "Mike Subelsky", "Olle Jonsson", "Vasily Kolesnikov", "William Tabi"]
	spec.license = "MIT"
	
	spec.cert_chain  = ["release.cert"]
	spec.signing_key = File.expand_path("~/.gem/release.pem")
	
	spec.homepage = "https://github.com/socketry/memory"
	
	spec.metadata = {
		"documentation_uri" => "https://socketry.github.io/memory/",
		"source_code_uri" => "https://github.com/socketry/memory.git",
	}
	
	spec.files = Dir.glob(["{bake,lib}/**/*", "*.md"], File::FNM_DOTMATCH, base: __dir__)
	
	spec.required_ruby_version = ">= 3.2"
	
	spec.add_dependency "bake", "~> 0.15"
	spec.add_dependency "console"
	spec.add_dependency "msgpack"
end
