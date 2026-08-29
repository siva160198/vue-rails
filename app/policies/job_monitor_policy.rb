class JobMonitorPolicy < ApplicationPolicy
  def index?
    user.can?("jobs.view")
  end

  def update?
    user.can?("jobs.update")
  end

  def destroy?
    update?
  end
end
