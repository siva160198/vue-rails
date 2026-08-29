module Api
  module V1
    module Admin
      class ApiDocsController < ApplicationController
        def show
          authorize :api_doc
          send_file Rails.root.join("docs/openapi.yml"), type: "application/yaml", disposition: "inline"
        end
      end
    end
  end
end
