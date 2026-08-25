class UserPolicy < ApplicationPolicy
  def index?
    user&.admin?
  end

  def update?
    user&.admin? && record != user
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      user&.admin? ? scope.all : scope.none
    end
  end
end
