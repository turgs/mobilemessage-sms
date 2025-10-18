# frozen_string_literal: true

require_relative "lib/mobilemessage/sms/version"

Gem::Specification.new do |spec|
  spec.name = "mobilemessage-sms"
  spec.version = MobileMessage::SMS::VERSION
  spec.authors = ["mobilemessage-sms contributors"]
  spec.email = ["contributors@example.com"]

  spec.summary = "Ruby gem for Mobile Message API SMS endpoints"
  spec.description = "A comprehensive Ruby gem for interacting with Mobile Message API, supporting SMS sending/receiving, " \
                     "webhooks, message tracking, account management, and number provisioning."
  spec.homepage = "https://github.com/turgs/mobilemessage-sms"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/turgs/mobilemessage-sms"
  spec.metadata["changelog_uri"] = "https://github.com/turgs/mobilemessage-sms/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # No external dependencies - using only standard library
  # This minimizes dependencies and security concerns
end
