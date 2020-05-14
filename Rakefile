require "govuk_app_config"

# rubocop:disable Lint/SuppressedException
begin
  require "rspec/core/rake_task"
  RSpec::Core::RakeTask.new(:spec)
rescue LoadError # rubocop:disable Lint/SuppressedException
end
# rubocop:enable Lint/SuppressedException

desc "Lint Ruby"
task :lint do
  sh "bundle exec rubocop"
end

Dir.glob("lib/tasks/*.rake").each { |r| load r }

task default: %i[lint spec]
