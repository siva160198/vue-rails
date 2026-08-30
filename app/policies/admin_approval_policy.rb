class AdminApprovalPolicy < ApplicationPolicy
  def index? = user&.can?("security_approvals.view")
  def update? = user&.can?("security_approvals.update") && record.requester_id != user.id

  class Scope < ApplicationPolicy::Scope
    def resolve
      user&.can?("security_approvals.view") ? scope.all : scope.none
    end
  end
end
