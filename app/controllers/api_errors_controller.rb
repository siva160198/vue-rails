class ApiErrorsController < ApplicationController
  allow_unauthenticated_access

  def not_found
    render_api_error("RESOURCE_NOT_FOUND", status: :not_found)
  end
end
