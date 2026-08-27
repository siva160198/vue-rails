class AuditLogPolicy < ApplicationPolicy
  def index?
    user&.can?("audit_logs.view")
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      user&.can?("audit_logs.view") ? scope.all : scope.none
    end
  end
end
