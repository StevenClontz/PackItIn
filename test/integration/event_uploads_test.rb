require "test_helper"

class EventUploadsTest < ActionDispatch::IntegrationTest
  def sign_in_as(username, password: "password123")
    post family_session_path, params: { family: { login: username, password: password } }
  end

  def blob_params
    data = "%PDF-1.4 flyer"
    { blob: { filename: "flyer.pdf", byte_size: data.bytesize, checksum: OpenSSL::Digest::MD5.base64digest(data), content_type: "application/pdf" } }
  end

  test "guests must sign in to upload" do
    assert_no_difference "ActiveStorage::Blob.count" do
      post event_uploads_path, params: blob_params, as: :json
    end
    assert_response :unauthorized
  end

  test "non-admins cannot upload" do
    sign_in_as "examplefamily"
    assert_no_difference "ActiveStorage::Blob.count" do
      post event_uploads_path, params: blob_params, as: :json
    end
    assert_response :forbidden
  end

  test "admins get a blob ready for direct upload" do
    sign_in_as "adminfamily"
    assert_difference "ActiveStorage::Blob.count", 1 do
      post event_uploads_path, params: blob_params, as: :json
    end
    assert_response :success
    json = response.parsed_body
    assert json["signed_id"].present?
    assert json.dig("direct_upload", "url").present?
  end
end
