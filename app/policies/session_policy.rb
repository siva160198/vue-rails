class SessionPolicy < ApplicationPolicy
  def index?
    user&.can?("sessions.view")
  end

  def destroy?
    user&.can?("sessions.delete") && (record.is_a?(Class) || record.user_id == user.id)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      user&.can?("sessions.view") ? scope.where(user: user) : scope.none
    end
  end
end
