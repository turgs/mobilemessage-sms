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
      to: "0412345678",
      message: "Test message",
      sender: "TestSender"
    )

    assert response.success?
    assert_equal 1, response.messages.count
    assert_match(/^msg_/, response.first_message_id)
    assert_equal 1, response.total_cost
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
    response = client.send_sms(to: "0412345678", message: "Test")

    assert response.success?
  end

  def test_send_sms_requires_from
    client = MobileMessage::SMS::Client.new(**sample_credentials)
    error = assert_raises(ArgumentError) do
      client.send_sms(to: "0412345678", message: "Test")
    end
    assert_match(/sender.*required/, error.message)
  end

  def test_send_bulk_success
    stub_api_request(
      method: :post,
      endpoint: "messages",
      response_body: sample_success_response(messages_count: 3)
    )

    client = MobileMessage::SMS::Client.new(**sample_credentials)
    messages = [
      { to: "0412345678", message: "Message 1", sender: "Sender" },
      { to: "0412345679", message: "Message 2", sender: "Sender" },
      { to: "0412345680", message: "Message 3", sender: "Sender" }
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
      to_numbers: ["0412345678", "0412345679"],
      message: "Broadcast message",
      sender: "Sender"
    )

    assert response.success?
    assert_equal 2, response.messages.count
  end

  def test_get_message_status
    stub_request(:get, "https://api.mobilemessage.com.au/v1/messages?message_id=msg_12345")
      .to_return(
        status: 200,
        body: sample_message_status_response.to_json,
        headers: { "Content-Type" => "application/json" }
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
      endpoint: "account",
      response_body: sample_balance_response
    )

    client = MobileMessage::SMS::Client.new(**sample_credentials)
    response = client.get_balance

    assert response.success?
    assert_equal 1000, response.balance
    refute response.low_balance?
  end

  def test_get_messages_empty
    stub_request(:get, "https://api.mobilemessage.com.au/v1/messages?type=inbound")
      .to_return(
        status: 200,
        body: { "error" => "No inbound or unsubscribe messages found." }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    client = MobileMessage::SMS::Client.new(**sample_credentials)
    response = client.get_messages

    assert response.success?
    assert_equal 0, response.messages.count
    assert response.empty?
  end

  def test_get_messages_with_results
    # API returns direct array when messages exist
    stub_request(:get, "https://api.mobilemessage.com.au/v1/messages?type=inbound")
      .to_return(
        status: 200,
        body: [
          {
            "to" => "61480808165",
            "message" => "What's up",
            "sender" => "61403309564",
            "received_at" => "2025-10-19 12:59:17",
            "type" => "inbound"
          }
        ].to_json,
        headers: { "Content-Type" => "application/json" }
      )

    client = MobileMessage::SMS::Client.new(**sample_credentials)
    response = client.get_messages

    assert response.success?
    assert_equal 1, response.messages.count
    refute response.empty?
    assert_equal "61403309564", response.messages.first.from
    assert_equal "What's up", response.messages.first.body
  end

  def test_authentication_error
    stub_request(:post, "https://api.mobilemessage.com.au/v1/messages")
      .to_return(status: 401, body: { error: { message: "Unauthorized" } }.to_json)

    client = MobileMessage::SMS::Client.new(**sample_credentials)
    
    error = assert_raises(MobileMessage::SMS::AuthenticationError) do
      client.send_sms(to: "0412345678", message: "Test", sender: "Sender")
    end
    assert_match(/Authentication failed/, error.message)
  end

  def test_insufficient_credits_error
    stub_request(:post, "https://api.mobilemessage.com.au/v1/messages")
      .to_return(
        status: 403,
        body: { error: { message: "Insufficient credits" } }.to_json
      )

    client = MobileMessage::SMS::Client.new(**sample_credentials)
    
    error = assert_raises(MobileMessage::SMS::InsufficientCreditsError) do
      client.send_sms(to: "0412345678", message: "Test", sender: "Sender")
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
      client.send_sms(to: "0412345678", message: "Test", sender: "Sender")
    end
    assert_equal 60, error.retry_after
  end

  def test_webhook_signature_verification
    client = MobileMessage::SMS::Client.new(**sample_credentials)
    payload = '{"test":"data"}'
    secret = "webhook_secret"
    
    # Generate valid signature
    require "openssl"
    valid_signature = OpenSSL::HMAC.hexdigest("SHA256", secret, payload)
    
    # Test valid signature
    assert client.verify_webhook_signature(
      payload: payload,
      signature: valid_signature,
      secret: secret
    )
    
    # Test invalid signature
    refute client.verify_webhook_signature(
      payload: payload,
      signature: "invalid_signature",
      secret: secret
    )
    
    # Test signature with different length (should not raise)
    refute client.verify_webhook_signature(
      payload: payload,
      signature: "short",
      secret: secret
    )
  end

  def test_parse_inbound_webhook
    client = MobileMessage::SMS::Client.new(**sample_credentials)
    payload = sample_inbound_webhook_payload
    
    message = client.parse_webhook(payload)
    
    assert_instance_of MobileMessage::SMS::InboundMessage, message
    assert_equal "61412345699", message.from
    assert_equal "61412345678", message.to
    assert_equal "Hello, this is message 1", message.body
    assert_equal "inbound", message.type
    assert message.inbound?
    assert_equal "db6190e1-1ce8-4cdd-b871-244257d57abc", message.original_message_id
    assert_equal "tracking001", message.original_custom_ref
  end

  def test_parse_status_webhook
    client = MobileMessage::SMS::Client.new(**sample_credentials)
    payload = sample_status_webhook_payload
    
    status = client.parse_webhook(payload)
    
    assert_instance_of MobileMessage::SMS::StatusUpdate, status
    assert_equal "044b035f-0396-4a47-8428-12d5273ab04a", status.message_id
    assert_equal "tracking001", status.custom_ref
    assert_equal "delivered", status.status
    assert status.delivered?
    refute status.failed?
  end
end
