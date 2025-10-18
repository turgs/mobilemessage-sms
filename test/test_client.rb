# frozen_string_literal: true

require "test_helper"

class TestClient < Minitest::Test
  include TestHelper

  def test_client_initialization
    client = MobileMessage::SMS::Client.new(**sample_credentials)
    assert_instance_of MobileMessage::SMS::Client, client
    assert_equal "test_user", client.config.username
    assert_equal "test_password", client.config.password
  end

  def test_client_initialization_with_options
    client = MobileMessage::SMS::Client.new(
      **sample_credentials,
      default_from: "MyBrand",
      response_format: :raw
    )
    assert_equal "MyBrand", client.config.default_from
    assert_equal :raw, client.config.response_format
  end

  def test_client_requires_username
    error = assert_raises(ArgumentError) do
      MobileMessage::SMS::Client.new(password: "test_password")
    end
    assert_match(/username is required/, error.message)
  end

  def test_client_requires_password
    error = assert_raises(ArgumentError) do
      MobileMessage::SMS::Client.new(username: "test_user")
    end
    assert_match(/password is required/, error.message)
  end

  def test_send_sms_success
    stub_api_request(
      method: :post,
      endpoint: "messages",
      response_body: sample_success_response
    )

    client = MobileMessage::SMS::Client.new(**sample_credentials)
    response = client.send_sms(
      to: "+61400000000",
      body: "Test message",
      from: "TestSender"
    )

    assert response.success?
    assert_equal 1, response.messages.count
    assert_match(/^msg_/, response.first_message_id)
  end

  def test_send_sms_uses_default_from
    stub_api_request(
      method: :post,
      endpoint: "messages",
      response_body: sample_success_response
    )

    client = MobileMessage::SMS::Client.new(
      **sample_credentials,
      default_from: "DefaultSender"
    )
    response = client.send_sms(to: "+61400000000", body: "Test")

    assert response.success?
  end

  def test_send_sms_requires_from
    client = MobileMessage::SMS::Client.new(**sample_credentials)
    error = assert_raises(ArgumentError) do
      client.send_sms(to: "+61400000000", body: "Test")
    end
    assert_match(/from.*required/, error.message)
  end

  def test_send_bulk_success
    stub_api_request(
      method: :post,
      endpoint: "messages",
      response_body: sample_success_response(messages_count: 3)
    )

    client = MobileMessage::SMS::Client.new(**sample_credentials)
    messages = [
      { to: "+61400000001", body: "Message 1", from: "Sender" },
      { to: "+61400000002", body: "Message 2", from: "Sender" },
      { to: "+61400000003", body: "Message 3", from: "Sender" }
    ]

    response = client.send_bulk(messages: messages)

    assert response.success?
    assert_equal 3, response.messages.count
  end

  def test_broadcast_success
    stub_api_request(
      method: :post,
      endpoint: "messages",
      response_body: sample_success_response(messages_count: 2)
    )

    client = MobileMessage::SMS::Client.new(**sample_credentials)
    response = client.broadcast(
      to_numbers: ["+61400000001", "+61400000002"],
      body: "Broadcast message",
      from: "Sender"
    )

    assert response.success?
    assert_equal 2, response.messages.count
  end

  def test_get_message_status
    stub_api_request(
      method: :get,
      endpoint: "messages/msg_12345",
      response_body: sample_message_status_response
    )

    client = MobileMessage::SMS::Client.new(**sample_credentials)
    response = client.get_message_status(message_id: "msg_12345")

    assert response.success?
    assert_equal "msg_12345", response.message_id
    assert response.delivered?
  end

  def test_get_balance
    stub_api_request(
      method: :get,
      endpoint: "account/balance",
      response_body: sample_balance_response
    )

    client = MobileMessage::SMS::Client.new(**sample_credentials)
    response = client.get_balance

    assert response.success?
    assert_equal 100.50, response.balance
    assert_equal "AUD", response.currency
    refute response.low_balance?
  end

  def test_get_messages
    stub_request(:get, "https://api.mobilemessage.com.au/v1/messages/received?page=1&per_page=100")
      .to_return(
        status: 200,
        body: sample_received_messages_response(count: 2).to_json,
        headers: { "Content-Type" => "application/json" }
      )

    client = MobileMessage::SMS::Client.new(**sample_credentials)
    response = client.get_messages

    assert response.success?
    assert_equal 2, response.messages.count
    assert_equal 2, response.total_count
  end

  def test_authentication_error
    stub_request(:post, "https://api.mobilemessage.com.au/v1/messages")
      .to_return(status: 401, body: { error: { message: "Unauthorized" } }.to_json)

    client = MobileMessage::SMS::Client.new(**sample_credentials)
    
    error = assert_raises(MobileMessage::SMS::AuthenticationError) do
      client.send_sms(to: "+61400000000", body: "Test", from: "Sender")
    end
    assert_match(/Authentication failed/, error.message)
  end

  def test_insufficient_credits_error
    stub_request(:post, "https://api.mobilemessage.com.au/v1/messages")
      .to_return(
        status: 402,
        body: { error: { message: "Insufficient credits" } }.to_json
      )

    client = MobileMessage::SMS::Client.new(**sample_credentials)
    
    error = assert_raises(MobileMessage::SMS::InsufficientCreditsError) do
      client.send_sms(to: "+61400000000", body: "Test", from: "Sender")
    end
    assert_match(/Insufficient credits/, error.message)
  end

  def test_rate_limit_error
    stub_request(:post, "https://api.mobilemessage.com.au/v1/messages")
      .to_return(
        status: 429,
        body: { error: { message: "Rate limit exceeded" } }.to_json,
        headers: { "Retry-After" => "60" }
      )

    client = MobileMessage::SMS::Client.new(**sample_credentials, auto_retry: false)
    
    error = assert_raises(MobileMessage::SMS::RateLimitError) do
      client.send_sms(to: "+61400000000", body: "Test", from: "Sender")
    end
    assert_equal 60, error.retry_after
  end
end
