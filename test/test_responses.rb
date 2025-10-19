# frozen_string_literal: true

require "test_helper"

class TestResponses < Minitest::Test
  include TestHelper

  def test_send_sms_response
    raw = sample_success_response
    response = MobileMessage::SMS::SendSmsResponse.new(raw)

    assert response.success?
    refute response.error?
    assert_equal 1, response.messages.count
    assert_equal 1, response.sent_count
    assert_equal 0, response.failed_count
    assert response.all_successful?
    refute response.has_failures?
  end

  def test_send_sms_response_with_failures
    raw = {
      "status" => "complete",
      "total_cost" => 2,
      "results" => [
        { "message_id" => "1", "status" => "success" },
        { "message_id" => "2", "status" => "failed" }
      ]
    }
    response = MobileMessage::SMS::SendSmsResponse.new(raw)

    assert_equal 1, response.sent_count
    assert_equal 1, response.failed_count
    refute response.all_successful?
    assert response.has_failures?
  end

  def test_message_status_response
    raw = sample_message_status_response
    response = MobileMessage::SMS::MessageStatusResponse.new(raw)

    assert response.success?
    assert_equal "msg_12345", response.message_id
    assert_equal "success", response.status
    assert response.delivered?  # "success" status means delivered
    refute response.pending?
    refute response.failed?
  end

  def test_message_status_pending
    raw = sample_message_status_response(status: "queued")
    response = MobileMessage::SMS::MessageStatusResponse.new(raw)

    assert response.pending?
    refute response.delivered?
    refute response.failed?
  end

  def test_balance_response
    raw = sample_balance_response(balance: 50)
    response = MobileMessage::SMS::BalanceResponse.new(raw)

    assert response.success?
    assert_equal 50, response.balance
    assert_equal "AUD", response.currency
    assert_equal "50 credits", response.formatted_balance
  end

  def test_balance_response_low_balance
    raw = sample_balance_response(balance: 5)
    response = MobileMessage::SMS::BalanceResponse.new(raw)

    assert response.low_balance?(10)
    refute response.low_balance?(5)
  end

  def test_inbound_message
    data = {
      "message_id" => "msg_123",
      "sender" => "+61400000001",
      "to" => "+61400000000",
      "message" => "Hello",
      "received_at" => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
      "type" => "inbound"
    }
    message = MobileMessage::SMS::InboundMessage.new(data)

    assert_equal "msg_123", message.message_id
    assert_equal "+61400000001", message.from
    assert_equal "+61400000000", message.to
    assert_equal "Hello", message.body
    assert_equal "inbound", message.type
    assert message.inbound?
    assert_instance_of Time, message.received_at
  end

  def test_status_update
    data = {
      "message_id" => "msg_123",
      "custom_ref" => "tracking001",
      "to" => "+61400000000",
      "sender" => "CompanyABC",
      "message" => "Hello",
      "status" => "delivered",
      "received_at" => Time.now.strftime("%Y-%m-%d %H:%M:%S")
    }
    status = MobileMessage::SMS::StatusUpdate.new(data)

    assert_equal "msg_123", status.message_id
    assert_equal "tracking001", status.custom_ref
    assert_equal "+61400000000", status.to
    assert_equal "CompanyABC", status.sender
    assert_equal "Hello", status.body
    assert_equal "delivered", status.status
    assert status.delivered?
    refute status.failed?
    assert_instance_of Time, status.received_at
  end

  def test_chainable_operations
    raw = sample_success_response
    response = MobileMessage::SMS::SendSmsResponse.new(raw)

    success_called = false
    error_called = false

    result = response
      .on_success { success_called = true }
      .on_error { error_called = true }

    assert success_called
    refute error_called
    assert_equal response, result
  end

  def test_bulk_response_collection
    collection = MobileMessage::SMS::BulkResponseCollection.new

    3.times { collection.add(MobileMessage::SMS::SendSmsResponse.new(sample_success_response)) }
    2.times { collection.add(MobileMessage::SMS::SendSmsResponse.new(sample_error_response)) }

    assert_equal 5, collection.total_count
    assert_equal 3, collection.success_count
    assert_equal 2, collection.failure_count
    assert_equal 60.0, collection.success_rate
    refute collection.all_successful?
    assert collection.any_failures?
  end
end
