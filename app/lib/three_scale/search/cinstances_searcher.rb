# frozen_string_literal: true

module ThreeScale::Search::CinstancesSearcher
  def find_service(id = params[:service_id])
    @service ||= (@plan || current_account).accessible_services.find(id) if id
  end

  def find_account(id = params[:account_id])
    @account ||= current_account.buyers.find(id) if id
  end

  def find_application_plans(id = params[:application_plan_id])
    @plan ||= (@service || current_account).application_plans.find(id) if id
  end

  def searcher(search = ThreeScale::Search.new(params[:search] || params))
    search.plan_id    = @plan.id    if find_application_plans
    search.account    = @account    if find_account
    search.service_id = @service.id if find_service
    search
  end

  def find_cinstances(search = searcher)
    @cinstances = current_user.accessible_cinstances
      .scope_search(search).order_by(params[:sort], params[:direction])
      .preload(:service, user_account: [:admin_user], plan: [:pricing_rules])
  end
end
