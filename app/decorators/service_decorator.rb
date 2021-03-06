class ServiceDecorator < Draper::Decorator
  delegate_all

  def link_to_application_plans
    stock_application_plans = application_plans.stock
    text = h.pluralize(stock_application_plans.size, 'application plan')
    link = h.link_to(text, plans_path)
    link << " (#{h.h published_application_plans.size} published)"

    link.html_safe
  end

  def plans_path
    h.admin_service_application_plans_path(self)
  end

  def applications_path
    h.admin_service_applications_path(self, search: { state: 'live' })
  end

  def link_to_live_applications
    live_cinstances = cinstances.live
    text = h.pluralize(live_cinstances.size, 'live application')

    if h.can?(:show, Cinstance)
      h.link_to text, applications_path
    else
      text
    end
  end

  def published_application_plans
    PlanDecorator.decorate_collection(application_plans.stock.published, context: { service: self })
  end
end
