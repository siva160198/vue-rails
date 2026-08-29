class ApiDocPolicy < ApplicationPolicy
  def show?
    user.can?("api_docs.view")
  end
end
