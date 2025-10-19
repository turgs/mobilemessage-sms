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
      "status" => "complete",
      "total_cost" => messages_count,
      "results" => Array.new(messages_count) do |i|
        {
          "message_id" => "msg_#{Time.now.to_i}_#{i}",
          "to" => "0412345678",
          "sender" => "TestSender",
          "message" => "Test message",
          "custom_ref" => "ref_#{i}",
          "status" => "success",
          "cost" => 1,
          "encoding" => "gsm7"
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

  def sample_balance_response(balance: 1000)
    {
      "status" => "complete",
      "credit_balance" => balance
    }
  end

  def sample_message_status_response(status: "success")
    {
      "status" => "complete",
      "results" => [
        {
          "message_id" => "msg_12345",
          "to" => "0412345678",
          "sender" => "TestSender",
          "message" => "Test message",
          "custom_ref" => "tracking001",
          "status" => status,
          "cost" => 1,
          "requested_at" => Time.now.strftime("%Y-%m-%d %H:%M:%S")
        }
      ]
    }
  end

  # Inbound messages are received via webhooks only, not polling
  # This helper is kept for backward compatibility but should not be used
  def sample_inbound_webhook_payload
    {
      "to" => "61412345678",
      "message" => "Hello, this is message 1",
      "sender" => "61412345699",
      "received_at" => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
      "type" => "inbound",
      "original_message_id" => "db6190e1-1ce8-4cdd-b871-244257d57abc",
      "original_custom_ref" => "tracking001"
    }
  end

  def sample_status_webhook_payload
    {
      "to" => "61412345678",
      "message" => "Hello, this is message 1",
      "sender" => "Mobile MSG",
      "custom_ref" => "tracking001",
      "status" => "delivered",
      "message_id" => "044b035f-0396-4a47-8428-12d5273ab04a",
      "received_at" => Time.now.strftime("%Y-%m-%d %H:%M:%S")
    }
  end
end
