# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in dependency.gemspec
gemspec

# QuickJS, which runs JavaScript Components, but whose native extension doesn't build on Windows, so it's left out
# there, where they can't run.
gem 'quickjs', '~> 0.22', platforms: :ruby

group :development do
  local_gems = {
    'dirload' => '../dirload',
    'lowevent' => '../lowevent',
    'lowkey' => '../lowkey',
    'lownode' => '../lownode',
    'lowtype' => '../lowtype',

    'antlers' => '../antlers',
    'expressions' => '../expressions',
    'observers' => '../observers',
    'plugs' => '../plugs',
    'providers' => '../providers',
    'trees' => '../trees'
  }

  local_gems.each do |name, relative_path|
    if File.exist?(File.expand_path(relative_path, __dir__))
      gem name, path: relative_path
    else
      gem name
    end
  end

  gem 'irb'
  gem 'rake'
  gem 'rspec'
  gem 'rubocop'
end
