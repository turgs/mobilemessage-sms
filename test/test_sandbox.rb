# frozen_string_literal: true

require "test_helper"

class TestSandbox < Minitest::Test
  include TestHelper

  def test_sandbox_mode_enabled
    client = MobileMessage::SMS::Client.new(
      **sample_credentials,
      sandbox_mode: true
    )
    
    assert client.config.sandbox?
    assert_instance_of MobileMessage::SMS::SandboxHttpClient, client.http_client
  end

  def test_sandbox_send_sms
    client = MobileMessage::SMS::Client.new(
      **sample_credentials,
      sandbox_mode: true,
      default_from: "TestSender"
    )

    response = client.send_sms(
      to: "+61400000000",
      body: "Test message"
    )

    assert response.success?
    assert_equal 1, response.messages.count
    assert_match(/^sandbox_msg_/, response.first_message_id)
  end

  def test_sandbox_get_balance
    client = MobileMessage::SMS::Client.new(
      **sample_credentials,
      sandbox_mode: true
    )

    response = client.get_balance

    assert response.success?
    assert_equal 100.50, response.balance
    assert_equal "Sandbox Account", response.account_name
  end

  def test_sandbox_get_message_status
    client = MobileMessage::SMS::Client.new(
      **sample_credentials,
      sandbox_mode: true
    )

    response = client.get_message_status(message_id: "test_123")

    assert response.success?
    assert_equal "test_123", response.message_id
    assert response.delivered?
  end

  def test_sandbox_get_messages
    client = MobileMessage::SMS::Client.new(
      **sample_credentials,
      sandbox_mode: true
    )

    response = client.get_messages

    assert response.success?
    assert_equal 1, response.messages.count
    assert_equal 1, response.total_count
  end

  def test_sandbox_broadcast
    client = MobileMessage::SMS::Client.new(
      **sample_credentials,
      sandbox_mode: true,
      default_from: "TestSender"
    )

    response = client.broadcast(
      to_numbers: ["+61400000001", "+61400000002", "+61400000003"],
      body: "Broadcast message"
    )

    assert response.success?
    assert_equal 3, response.messages.count
    assert response.all_successful?
  end
end
