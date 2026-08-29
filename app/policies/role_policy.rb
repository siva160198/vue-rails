class RolePolicy < ApplicationPolicy
  def index?
    user&.can?("roles.view")
  end

  def create?
    user&.can?("roles.create")
  end

  def show?
    user&.can?("roles.view")
  end

  def update?
    user&.can?("roles.update")
  end

  def destroy?
    user&.can?("roles.delete") && record.destroyable?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      user&.can?("roles.view") ? scope.all : scope.none
    end
  end
end
