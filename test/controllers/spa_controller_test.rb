require "test_helper"
require "tmpdir"

class SpaControllerTest < ActionDispatch::IntegrationTest
  test "returns not found when the production frontend has not been built" do
    get root_url

    assert_response :not_found
  end

  test "serves the built Vue application for frontend routes" do
    Dir.mktmpdir do |directory|
      public_path = Pathname(directory)
      FileUtils.mkdir_p(public_path.join("frontend"))
      File.write(public_path.join("frontend/index.html"), "<!doctype html><title>Vue application</title>")

      original_method = SpaController.instance_method(:frontend_index_file)
      SpaController.define_method(:frontend_index_file) { public_path.join("frontend/index.html") }
      SpaController.send(:private, :frontend_index_file)
      get "/admin/users"

      assert_response :success
      assert_includes response.body, "Vue application"
    ensure
      SpaController.define_method(:frontend_index_file, original_method) if original_method
      SpaController.send(:private, :frontend_index_file)
    end
  end
end
