# frozen_string_literal: true

class Api::ApplicationsController < Api::BaseController
  before_action :find_service
  before_action :activate_submenu

  include ThreeScale::Search::Helpers
  include ThreeScale::Search::CinstancesSearcher

  activate_menu :main_menu => :serviceadmin, sidebar: :applications
  sublayout 'api/service'

  def index
    @states = Cinstance.allowed_states.collect(&:to_s).sort
    @search = searcher
    service_application_plans = @service.application_plans
    @application_plans = service_application_plans.stock
    @stock_and_custom_application_plans = service_application_plans.size

    @cinstances = find_cinstances(searcher).paginate(pagination_params)
    @show_services = false
  end
end
