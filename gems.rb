# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020, by Samuel Williams.

source "https://rubygems.org"

# Specify your gem's dependencies in db.gemspec
gemspec

group :maintenance, optional: true do
	gem "bake-modernize"
	gem "bake-bundler"
	
	gem "utopia-project"
end

group :test do
	gem 'longhorn', path: 'fixtures/gems/longhorn-0.1.0'
end
