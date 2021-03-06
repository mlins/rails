require 'abstract_unit'
require 'logger'
require 'pp' # require 'pp' early to prevent hidden_methods from not picking up the pretty-print methods until too late

# Provide some controller to run the tests on.
module Submodule
  class ContainedEmptyController < ActionController::Base
  end
  class ContainedNonEmptyController < ActionController::Base
    def public_action
      render :nothing => true
    end

    hide_action :hidden_action
    def hidden_action
      raise "Noooo!"
    end

    def another_hidden_action
    end
    hide_action :another_hidden_action
  end
  class SubclassedController < ContainedNonEmptyController
    hide_action :public_action # Hiding it here should not affect the superclass.
  end
end
class EmptyController < ActionController::Base
end
class NonEmptyController < ActionController::Base
  def public_action
    render :nothing => true
  end

  hide_action :hidden_action
  def hidden_action
  end
end

class MethodMissingController < ActionController::Base

  hide_action :shouldnt_be_called
  def shouldnt_be_called
    raise "NO WAY!"
  end

protected

  def method_missing(selector)
    render :text => selector.to_s
  end

end

class DefaultUrlOptionsController < ActionController::Base
  def default_url_options_action
    render :nothing => true
  end

  def default_url_options(options = nil)
    { :host => 'www.override.com', :action => 'new', :bacon => 'chunky' }
  end
end

class ControllerClassTests < Test::Unit::TestCase
  def test_controller_path
    assert_equal 'empty', EmptyController.controller_path
    assert_equal EmptyController.controller_path, EmptyController.new.controller_path
    assert_equal 'submodule/contained_empty', Submodule::ContainedEmptyController.controller_path
    assert_equal Submodule::ContainedEmptyController.controller_path, Submodule::ContainedEmptyController.new.controller_path
  end
  def test_controller_name
    assert_equal 'empty', EmptyController.controller_name
    assert_equal 'contained_empty', Submodule::ContainedEmptyController.controller_name
 end
end

class ControllerInstanceTests < Test::Unit::TestCase
  def setup
    @empty = EmptyController.new
    @contained = Submodule::ContainedEmptyController.new
    @empty_controllers = [@empty, @contained, Submodule::SubclassedController.new]

    @non_empty_controllers = [NonEmptyController.new,
                              Submodule::ContainedNonEmptyController.new]
  end

  def test_action_methods
    @empty_controllers.each do |c|
      hide_mocha_methods_from_controller(c)
      assert_equal Set.new, c.class.__send__(:action_methods), "#{c.controller_path} should be empty!"
    end
    @non_empty_controllers.each do |c|
      hide_mocha_methods_from_controller(c)
      assert_equal Set.new(%w(public_action)), c.class.__send__(:action_methods), "#{c.controller_path} should not be empty!"
    end
  end

  protected
    # Mocha adds some public instance methods to Object that would be
    # considered actions, so explicitly hide_action them.
    def hide_mocha_methods_from_controller(controller)
      mocha_methods = [
        :expects, :mocha, :mocha_inspect, :reset_mocha, :stubba_object,
        :stubba_method, :stubs, :verify, :__metaclass__, :__is_a__, :to_matcher,
      ]
      controller.class.__send__(:hide_action, *mocha_methods)
    end
end


class PerformActionTest < ActionController::TestCase
  class MockLogger
    attr_reader :logged

    def initialize
      @logged = []
    end

    def method_missing(method, *args)
      @logged << args.first.to_s
    end
  end

  def use_controller(controller_class)
    @controller = controller_class.new

    # enable a logger so that (e.g.) the benchmarking stuff runs, so we can get
    # a more accurate simulation of what happens in "real life".
    @controller.logger = Logger.new(nil)

    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    @request.host = "www.nextangle.com"

    rescue_action_in_public!
  end

  def test_get_on_priv_should_show_selector
    use_controller MethodMissingController
    get :shouldnt_be_called
    assert_response :success
    assert_equal 'shouldnt_be_called', @response.body
  end

  def test_method_missing_is_not_an_action_name
    use_controller MethodMissingController

    assert ! @controller.__send__(:action_method?, 'method_missing')

    get :method_missing
    assert_response :success
    assert_equal 'method_missing', @response.body
  end

  def test_get_on_hidden_should_fail
    use_controller NonEmptyController
    assert_raise(ActionController::UnknownAction) { get :hidden_action }
    assert_raise(ActionController::UnknownAction) { get :another_hidden_action }
  end
end

class DefaultUrlOptionsTest < ActionController::TestCase
  tests DefaultUrlOptionsController

  def setup
    super
    @request.host = 'www.example.com'
    rescue_action_in_public!
  end

  def test_default_url_options_are_used_if_set
    with_routing do |set|
      set.draw do |map|
        match 'default_url_options', :to => 'default_url_options#default_url_options_action', :as => :default_url_options
        match ':controller/:action'
      end

      get :default_url_options_action # Make a dummy request so that the controller is initialized properly.

      assert_equal 'http://www.override.com/default_url_options/new?bacon=chunky', @controller.url_for(:controller => 'default_url_options')
      assert_equal 'http://www.override.com/default_url_options?bacon=chunky', @controller.send(:default_url_options_url)
    end
  end
end

class EmptyUrlOptionsTest < ActionController::TestCase
  tests NonEmptyController

  def setup
    super
    @request.host = 'www.example.com'
    rescue_action_in_public!
  end

  def test_ensure_url_for_works_as_expected_when_called_with_no_options_if_default_url_options_is_not_set
    get :public_action
    assert_equal "http://www.example.com/non_empty/public_action", @controller.url_for
  end
end

class EnsureNamedRoutesWorksTicket22BugTest < ActionController::TestCase
  def test_named_routes_still_work
    with_routing do |set|
      set.draw do |map|
        resources :things
      end
      EmptyController.send :include, ActionController::UrlWriter

      assert_equal '/things', EmptyController.new.send(:things_path)
    end
  end
end
