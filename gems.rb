source "https://rubygems.org"

# Specify your gem's dependencies in db.gemspec
gemspec

group :maintenance, optional: true do
	gem "bake-modernize"
	gem "bake-bundler"
	
	gem "utopia-project"
end

group :test do
	gem 'longhorn', path: 'spec/fixtures/gems/longhorn-0.1.0'
end
