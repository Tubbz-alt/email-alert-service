# This file was generated by the `rspec --init` command. Conventionally, all
# specs live under a `spec` directory, which RSpec adds to the `$LOAD_PATH`.
# The generated `.rspec` file contains `--require spec_helper` which will cause this
# file to always be loaded, without a need to explicitly require it in any files.
#
# Given that it is always loaded, you are encouraged to keep this file as
# light-weight as possible. Requiring heavyweight dependencies from this file
# will add to the boot time of your test suite on EVERY test run, even for an
# individual file that may not need all of that loaded. Instead, consider making
# a separate helper file that requires the additional dependencies and performs
# the additional setup, and require it from the spec files that actually need it.
#
# The `.rspec` file also contains a few flags that are not defaults but that
# users commonly want.
#
# See http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration

ENV["GOVUK_ENV"] = "test"

require_relative "../email_alert_service/environment"
Dir[File.join(EmailAlertService.config.app_root, "spec/support/**/*.rb")].each { |f| require f }

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.disable_monkey_patching!
  config.expose_dsl_globally = false
  config.order = :random

  config.before(:each, type: :integration) do
    @test_config = EmailAlertService::Config.new(ENV["GOVUK_ENV"])

    rabbit_options = @test_config.rabbitmq.reject {|(key, _)| key == :queue }

    @connection = Bunny.new(rabbit_options)
    @connection.start

    @write_channel = @connection.create_channel
    @read_channel = @connection.create_channel

    @exchange = @write_channel.topic(@test_config.rabbitmq.fetch(:exchange), passive: true)
    @read_queue = @read_channel.queue(@test_config.rabbitmq.fetch(:queue))
  end

  config.after(:each, type: :integration) do
    @connection.close
  end

  config.include(ListenerTestHelpers, type: :integration)
end