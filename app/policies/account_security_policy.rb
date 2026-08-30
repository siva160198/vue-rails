class AccountSecurityPolicy < ApplicationPolicy
  def show?
    user&.can?("account_security.view")
  end

  def update?
    user&.can?("account_security.update")
  end
end
