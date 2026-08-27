class RolePolicy < ApplicationPolicy
  def index?
    user&.can?("roles.view")
  end

  def create?
    user&.can?("roles.manage")
  end

  def update?
    user&.can?("roles.manage")
  end

  def destroy?
    user&.can?("roles.manage") && record.destroyable?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      user&.can?("roles.view") ? scope.all : scope.none
    end
  end
end
