require 'test_helper'

class Provider::Admin::CMS::SwitchesControllerTest < ActionDispatch::IntegrationTest
  test 'Finance is globally disabled' do
    provider = FactoryGirl.create(:provider_account)
    login! provider
    plan = ApplicationPlan.new(issuer: master_account.first_service!, name: 'enterprise')
    provider.force_upgrade_to_provider_plan!(plan)

    ThreeScale.config.stubs(onpremises: false)
    get provider_admin_cms_switches_path
    assert_response :success
    assert_select '#switch-finance-toggle'

    ThreeScale.config.stubs(onpremises: true)
    get provider_admin_cms_switches_path
    assert_response :success
    assert_select '#switch-finance-toggle', true
    assert_select %Q(table#switches th), text: 'Finance', count: 1
  end

  test "show a  switch" do
    @provider.settings.update_attribute(:account_plans_switch,'hidden')

    xhr :put, provider_admin_cms_switch_path('account_plans', format: :js)
    assert_response :success

    assert @provider.settings.reload.switches[:account_plans].visible?, 'not visible'
  end
end

