# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "mobilemessage"

require "minitest/autorun"
require "webmock/minitest"
require "json"

# Configure WebMock
WebMock.disable_net_connect!(allow_localhost: true)

module TestHelper
  def setup
    WebMock.reset!
  end

  def stub_api_request(method:, endpoint:, response_body:, status: 200, headers: {})
    url = "https://api.mobilemessage.com.au/v1/#{endpoint}"
    default_headers = {
      "Content-Type" => "application/json",
      "Accept" => "application/json"
    }

    stub_request(method, url)
      .to_return(
        status: status,
        body: response_body.to_json,
        headers: default_headers.merge(headers)
      )
  end

  def sample_credentials
    { username: "test_user", password: "test_password" }
  end

  def sample_success_response(messages_count: 1)
    {
      "success" => true,
      "messages" => Array.new(messages_count) do |i|
        {
          "message_id" => "msg_#{Time.now.to_i}_#{i}",
          "to" => "+61400000000",
          "from" => "TestSender",
          "body" => "Test message",
          "status" => "queued"
        }
      end
    }
  end

  def sample_error_response(message: "Error occurred", code: "ERROR")
    {
      "success" => false,
      "error" => {
        "message" => message,
        "code" => code
      }
    }
  end

  def sample_balance_response(balance: 100.50)
    {
      "success" => true,
      "balance" => balance,
      "currency" => "AUD",
      "account_name" => "Test Account"
    }
  end

  def sample_message_status_response(status: "delivered")
    {
      "success" => true,
      "message" => {
        "message_id" => "msg_12345",
        "to" => "+61400000000",
        "from" => "TestSender",
        "body" => "Test message",
        "status" => status,
        "delivered_at" => Time.now.iso8601
      }
    }
  end

  def sample_received_messages_response(count: 1, page: 1)
    {
      "success" => true,
      "messages" => Array.new(count) do |i|
        {
          "message_id" => "received_#{i}",
          "from" => "+61400000001",
          "to" => "+61400000000",
          "body" => "Received message #{i}",
          "received_at" => Time.now.iso8601,
          "unicode" => false
        }
      end,
      "total_count" => count,
      "page" => page,
      "per_page" => 100
    }
  end
end
