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
      to: "0412345678",
      message: "Test message"
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
    assert_equal 1000, response.balance
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

  def test_sandbox_get_messages_raises_not_implemented
    client = MobileMessage::SMS::Client.new(
      **sample_credentials,
      sandbox_mode: true
    )

    error = assert_raises(NotImplementedError) do
      client.get_messages
    end
    assert_match(/webhook/, error.message)
  end

  def test_sandbox_broadcast
    client = MobileMessage::SMS::Client.new(
      **sample_credentials,
      sandbox_mode: true,
      default_from: "TestSender"
    )

    response = client.broadcast(
      to_numbers: ["0412345678", "0412345679", "0412345680"],
      message: "Broadcast message"
    )

    assert response.success?
    assert_equal 3, response.messages.count
    assert response.all_successful?
  end
end
