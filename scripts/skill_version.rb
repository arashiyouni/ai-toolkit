#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Bump a skill's build version in SKILL.md and marketplace.json.
# Shared by CI (skills-release.yml) and manual release (release.sh).
#
# Usage: ruby scripts/skill_version.rb <skill-path> [build]
#   build  - set version to this exact value (positive integer)
#            if omitted, increments current version by 1
#            if current version is missing, bootstraps from 0 → 1
#
# Outputs the new build number to stdout.

require "yaml"
require "json"
require "pathname"

path = ARGV[0] || abort("Usage: #{$0} <skill-path> [build]")
set_build = ARGV[1]

abort("File not found: #{path}") unless File.exist?(path)

# Parse SKILL.md frontmatter
content = File.read(path)
abort("Missing frontmatter in #{path}") unless content =~ /\A---\n(.*?)\n---\n/m
frontmatter = $1
body = $'

data = YAML.safe_load(frontmatter, permitted_classes: [Symbol]) || {}
data["metadata"] ||= {}

current = data.dig("metadata", "version")
current = 0 unless current && current.to_s.match?(/\A\d+\z/)

new_build = set_build ? Integer(set_build) : current.to_i + 1
data["metadata"]["version"] = new_build

new_frontmatter = YAML.dump(data).sub(/\A---\n/, "")
File.write(path, "---\n#{new_frontmatter}---\n#{body}")

# Update marketplace.json
root = Pathname.new(__dir__).join("..").expand_path
marketplace_path = root.join("marketplace.json").to_s

if File.exist?(marketplace_path)
  skill_name = data["name"] || File.basename(File.dirname(path))
  marketplace = JSON.parse(File.read(marketplace_path))
  entry = marketplace["skills"]&.find { |s| s["name"] == skill_name }
  abort("#{skill_name} missing from marketplace.json") unless entry
  entry["version"] = new_build
  File.write(marketplace_path, JSON.pretty_generate(marketplace) + "\n")
end

puts new_build
