class ProfilePolicy < ApplicationPolicy
  def show?
    user&.can?("profile.view")
  end

  def update?
    user&.can?("profile.update")
  end

  def destroy?
    update?
  end
end
