# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2013-2020, by Sam Saffron.
# Copyright, 2015-2018, by Dave Gynn.
# Copyright, 2015, by Vincent Woo.
# Copyright, 2015, by Boris Staal.
# Copyright, 2016, by Hamdi Akoğuz.
# Copyright, 2018, by Jonas Peschla.
# Copyright, 2020, by Jean Boussier.
# Copyright, 2020-2025, by Samuel Williams.

module Memory
	# Cache for storing and looking up allocation metadata.
	# Caches gem names, file locations, class names, and string values to reduce memory overhead during profiling.
	class Cache
		# Initialize a new cache with empty lookup tables.
		def initialize
			@gem_guess_cache = Hash.new
			@location_cache = Hash.new {|h, k| h[k] = Hash.new.compare_by_identity}
			@class_name_cache = Hash.new.compare_by_identity
			@string_cache = Hash.new
		end
		
		# Guess the gem or library name from a file path.
		# @parameter path [String] The file path to analyze.
		# @returns [String] The guessed gem name, stdlib component, or "other".
		def guess_gem(path)
			@gem_guess_cache[path] ||=
				if /(\/gems\/.*)*\/gems\/(?<gemname>[^\/]+)/ =~ path
					gemname
				elsif /\/rubygems[\.\/]/ =~ path
					"rubygems"
				elsif /ruby\/2\.[^\/]+\/(?<stdlib>[^\/\.]+)/ =~ path
					stdlib
				elsif /(?<app>[^\/]+\/(bin|app|lib))/ =~ path
					app
				else
					"other"
				end
		end
		
		# Look up and cache a file location string.
		# @parameter file [String] The source file path.
		# @parameter line [Integer] The line number.
		# @returns [String] The formatted location string "file:line".
		def lookup_location(file, line)
			@location_cache[file][line] ||= "#{file}:#{line}"
		end
		
		# Look up and cache a class name.
		# @parameter klass [Class] The class object.
		# @returns [String] The class name or `unknown` if unavailable.
		def lookup_class_name(klass)
			@class_name_cache[klass] ||= ((klass.is_a?(Class) && klass.name) || "unknown").to_s
		end
		
		# Look up and cache a string value.
		# Strings are truncated to 64 characters to reduce memory usage.
		# @parameter obj [String] The string object to cache.
		# @returns [String] A cached copy of the string (truncated to 64 characters).
		def lookup_string(obj)
			# This string is shortened to 200 characters which is what the string report shows
			# The string report can still list unique strings longer than 200 characters
			#   separately because the object_id of the shortened string will be different
			@string_cache[obj] ||= String.new << obj[0, 64]
		rescue RuntimeError => e
			# It is possible for the String to be temporarily locked from another Fiber
			# which raises an error when we try to use it as a hash key.
			# ie: Socket#read locks a buffer string while reading data into it.
			# In this case we dup the string to get an unlocked copy.
			if e.message == "can't modify string; temporarily locked"
				@string_cache[obj.dup] ||= String.new << obj[0, 64]
			else
				raise
			end
		end
	end
end
