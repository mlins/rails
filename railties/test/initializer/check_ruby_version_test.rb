require "isolation/abstract_unit"

module InitializerTests
  class CheckRubyVersionTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      boot_rails
    end

    test "rails initializes with ruby 1.8.7 or later" do
      if RUBY_VERSION < '1.8.7'
        assert_rails_does_not_boot
      else
        assert_rails_boots
      end
    end

    def assert_rails_boots
      assert_nothing_raised "It appears that rails does not boot" do
        require "rails"
      end
    end

    def assert_rails_does_not_boot
      $stderr = File.open("/dev/null", "w")
      assert_raises(SystemExit) do
        require "rails"
      end
    end
  end
end
