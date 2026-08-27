class DashboardPolicy < ApplicationPolicy
  def show?
    user&.can?("dashboard.view")
  end
end
