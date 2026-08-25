class SpaController < ApplicationController
  allow_unauthenticated_access

  def index
    index_file = frontend_index_file
    return head :not_found unless index_file.exist?

    send_file index_file, disposition: :inline, type: "text/html"
  end

  private
    def frontend_index_file
      Rails.public_path.join("frontend/index.html")
    end
end
