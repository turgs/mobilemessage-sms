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
      "success" => true,
      "messages" => [
        { "message_id" => "1", "status" => "queued" },
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
    assert_equal "delivered", response.status
    assert response.delivered?
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
    raw = sample_balance_response(balance: 50.25)
    response = MobileMessage::SMS::BalanceResponse.new(raw)

    assert response.success?
    assert_equal 50.25, response.balance
    assert_equal "AUD", response.currency
    assert_equal "AUD 50.25", response.formatted_balance
  end

  def test_balance_response_low_balance
    raw = sample_balance_response(balance: 5.0)
    response = MobileMessage::SMS::BalanceResponse.new(raw)

    assert response.low_balance?(10)
    refute response.low_balance?(5)
  end

  def test_inbound_message
    data = {
      "message_id" => "msg_123",
      "from" => "+61400000001",
      "to" => "+61400000000",
      "body" => "Hello",
      "received_at" => Time.now.iso8601,
      "unicode" => false
    }
    message = MobileMessage::SMS::InboundMessage.new(data)

    assert_equal "msg_123", message.message_id
    assert_equal "+61400000001", message.from
    assert_equal "+61400000000", message.to
    assert_equal "Hello", message.body
    refute message.unicode?
    assert_instance_of Time, message.received_at
  end

  def test_messages_list_response
    raw = sample_received_messages_response(count: 5, page: 1)
    raw["per_page"] = 2
    response = MobileMessage::SMS::MessagesListResponse.new(raw)

    assert response.success?
    assert_equal 5, response.messages.count
    assert_equal 5, response.total_count
    assert_equal 1, response.page
    assert_equal 2, response.per_page
    assert_equal 3, response.total_pages
    assert response.has_more?

    # Test each_message iterator
    count = 0
    response.each_message { |msg| count += 1 }
    assert_equal 5, count
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
