class UserPolicy < ApplicationPolicy
  def index?
    user&.can?("users.view")
  end

  def update?
    user&.can?("users.update") && record != user
  end

  def create?
    user&.can?("users.create")
  end

  def new?
    create?
  end

  def show?
    user&.can?("users.view")
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      user&.can?("users.view") ? scope.all : scope.none
    end
  end
end
