require 'test_helper'

class DashboardControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @account = accounts(:one)
    @user = users(:one)
    @user.update!(account: @account)
    sign_in @user
  end

  test "should get index" do
    get dashboard_url
    assert_response :success
    assert_select 'h1', text: /Welcome back/
  end

  test "should get index as json" do
    get dashboard_url(format: :json)
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert json_response.key?('overview')
    assert json_response.key?('activity')
    assert json_response.key?('performance')
    assert json_response.key?('realtime')
    assert json_response.key?('insights')
  end

  test "should redirect to onboarding if not completed" do
    # Create incomplete onboarding progress
    @user.onboarding_progress = OnboardingProgress.new(
      current_step: 'welcome',
      completed: false
    )
    @user.save!

    get dashboard_url
    assert_redirected_to onboarding_path
  end

  test "should show dashboard if onboarding completed" do
    # Create completed onboarding progress
    @user.onboarding_progress = OnboardingProgress.new(
      current_step: 'completed',
      completed: true,
      completed_at: Time.current
    )
    @user.save!

    get dashboard_url
    assert_response :success
  end

  test "should display correct overview stats" do
    get dashboard_url
    assert_response :success
    
    # Check that overview stats are calculated
    assert assigns(:overview_stats)
    assert assigns(:overview_stats)[:campaigns]
    assert assigns(:overview_stats)[:contacts]
    assert assigns(:overview_stats)[:emails]
    assert assigns(:overview_stats)[:revenue]
  end

  test "should provide recent activity data" do
    get dashboard_url
    assert_response :success
    
    assert assigns(:recent_activity)
    assert_kind_of Array, assigns(:recent_activity)
  end

  test "should provide quick actions" do
    get dashboard_url
    assert_response :success
    
    assert assigns(:quick_actions)
    assert_kind_of Array, assigns(:quick_actions)
    
    # Should have priority-sorted actions
    priorities = assigns(:quick_actions).map { |a| a[:priority] }
    assert priorities.any?
  end

  test "should provide growth insights" do
    get dashboard_url
    assert_response :success
    
    assert assigns(:growth_insights)
    assert_kind_of Array, assigns(:growth_insights)
  end

  test "should provide realtime stats" do
    get dashboard_url
    assert_response :success
    
    assert assigns(:realtime_stats)
    assert assigns(:realtime_stats).key?(:active_campaigns)
    assert assigns(:realtime_stats).key?(:recent_opens)
    assert assigns(:realtime_stats).key?(:recent_clicks)
    assert assigns(:realtime_stats).key?(:online_team_members)
  end

  test "should handle empty data gracefully" do
    # Clear all campaigns and contacts
    @account.campaigns.destroy_all
    @account.contacts.destroy_all
    
    get dashboard_url
    assert_response :success
    
    # Should still render without errors
    assert assigns(:overview_stats)
    assert_equal 0, assigns(:overview_stats)[:campaigns][:total]
    assert_equal 0, assigns(:overview_stats)[:contacts][:total]
  end
end