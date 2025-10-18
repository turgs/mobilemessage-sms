# frozen_string_literal: true

module MobileMessage
  module SMS
    # Base response wrapper with enhanced convenience methods
    class BaseResponse
      attr_reader :raw_response

      def initialize(response)
        @raw_response = response
      end

      # Allow hash-like access to raw response
      def [](key)
        @raw_response[key]
      end

      def dig(*keys)
        @raw_response.dig(*keys)
      end

      # Check if response indicates success
      def success?
        @raw_response["success"] == true
      end

      def error?
        !success?
      end

      # Get error information if present
      def error_message
        @raw_response.dig("error", "message")
      end

      def error_code
        @raw_response.dig("error", "code")
      end

      # Chainable operations
      def on_success
        yield self if success?
        self
      end

      def on_error
        yield self if error?
        self
      end

      def to_h
        @raw_response
      end
    end

    # Response for sending SMS messages
    class SendSmsResponse < BaseResponse
      def messages
        @raw_response["messages"] || []
      end

      def message_ids
        messages.map { |m| m["message_id"] }.compact
      end

      def first_message_id
        message_ids.first
      end

      def sent_count
        messages.count { |m| m["status"] == "queued" || m["status"] == "sent" }
      end

      def failed_count
        messages.count { |m| m["status"] == "failed" }
      end

      def all_successful?
        success? && messages.any? && failed_count.zero?
      end

      def has_failures?
        failed_count > 0
      end

      # Iterator for messages
      def each_message(&block)
        messages.each(&block)
      end

      # Get specific message by index
      def message_at(index)
        messages[index]
      end
    end

    # Response for checking message status
    class MessageStatusResponse < BaseResponse
      def message
        @raw_response["message"] || {}
      end

      def message_id
        message["message_id"]
      end

      def status
        message["status"]
      end

      def to
        message["to"]
      end

      def from
        message["from"]
      end

      def body
        message["body"]
      end

      def delivered?
        status == "delivered"
      end

      def pending?
        status == "queued" || status == "sent"
      end

      def failed?
        status == "failed" || status == "rejected"
      end

      def delivery_timestamp
        return nil unless message["delivered_at"]

        Time.parse(message["delivered_at"]) rescue nil
      end
    end

    # Response for checking account balance
    class BalanceResponse < BaseResponse
      def balance
        @raw_response["balance"] || 0
      end

      def currency
        @raw_response["currency"] || "AUD"
      end

      def account_name
        @raw_response["account_name"]
      end

      def low_balance?(threshold = 10)
        balance < threshold
      end

      def formatted_balance
        "#{currency} #{balance}"
      end
    end

    # Response for receiving SMS messages (webhook data)
    class InboundMessage
      attr_reader :raw_data

      def initialize(data)
        @raw_data = data
      end

      def message_id
        @raw_data["message_id"]
      end

      def from
        @raw_data["from"]
      end

      def to
        @raw_data["to"]
      end

      def body
        @raw_data["body"]
      end

      def received_at
        return nil unless @raw_data["received_at"]

        Time.parse(@raw_data["received_at"]) rescue nil
      end

      def unicode?
        @raw_data["unicode"] == true
      end

      def to_h
        @raw_data
      end
    end

    # Response for listing messages
    class MessagesListResponse < BaseResponse
      def messages
        (@raw_response["messages"] || []).map { |m| InboundMessage.new(m) }
      end

      def total_count
        @raw_response["total_count"] || messages.count
      end

      def page
        @raw_response["page"] || 1
      end

      def per_page
        @raw_response["per_page"] || 100
      end

      def total_pages
        return 1 if per_page.zero?

        (total_count.to_f / per_page).ceil
      end

      def has_more?
        page < total_pages
      end

      def each_message(&block)
        messages.each(&block)
      end
    end

    # Bulk response collection for multiple operations
    class BulkResponseCollection
      attr_reader :responses

      def initialize(responses = [])
        @responses = responses
      end

      def add(response)
        @responses << response
        self
      end

      def success_count
        @responses.count(&:success?)
      end

      def failure_count
        @responses.count(&:error?)
      end

      def total_count
        @responses.count
      end

      def success_rate
        return 0.0 if total_count.zero?

        (success_count.to_f / total_count * 100).round(2)
      end

      def all_successful?
        @responses.all?(&:success?)
      end

      def any_failures?
        @responses.any?(&:error?)
      end

      def each_response(&block)
        @responses.each(&block)
      end

      def to_h
        {
          total: total_count,
          success: success_count,
          failures: failure_count,
          success_rate: success_rate,
          responses: @responses.map(&:to_h)
        }
      end
    end
  end
end
