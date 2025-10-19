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
        @raw_response["status"] == "complete"
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
        @raw_response["results"] || []
      end

      def message_ids
        messages.map { |m| m["message_id"] }.compact
      end

      def first_message_id
        message_ids.first
      end

      def sent_count
        messages.count { |m| m["status"] == "success" || m["status"] == "queued" || m["status"] == "sent" }
      end

      def failed_count
        messages.count { |m| m["status"] == "failed" || m["status"] == "error" }
      end

      def all_successful?
        success? && messages.any? && failed_count.zero?
      end

      def has_failures?
        failed_count > 0
      end

      def total_cost
        @raw_response["total_cost"] || 0
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
      def results
        @raw_response["results"] || []
      end

      def message
        results.first || {}
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

      def sender
        message["sender"]
      end

      def body
        message["message"]
      end

      def custom_ref
        message["custom_ref"]
      end

      def cost
        message["cost"]
      end

      def delivered?
        status == "delivered" || status == "success"
      end

      def pending?
        status == "queued" || status == "sent"
      end

      def failed?
        status == "failed" || status == "rejected" || status == "error"
      end

      def requested_at
        return nil unless message["requested_at"]

        Time.parse(message["requested_at"])
      rescue ArgumentError, TypeError
        nil
      end

      # Legacy compatibility
      alias from sender
      alias delivery_timestamp requested_at
    end

    # Response for checking account balance
    class BalanceResponse < BaseResponse
      def balance
        @raw_response["credit_balance"] || 0
      end

      # Legacy alias
      alias credit_balance balance

      def currency
        "AUD"  # Mobile Message API uses AUD
      end

      def account_name
        @raw_response["account_name"]
      end

      def low_balance?(threshold = 10)
        balance < threshold
      end

      def formatted_balance
        "#{balance} credits"
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

      def original_message_id
        @raw_data["original_message_id"]
      end

      def original_custom_ref
        @raw_data["original_custom_ref"]
      end

      def from
        @raw_data["sender"]
      end

      # Legacy compatibility
      alias sender from

      def to
        @raw_data["to"]
      end

      def body
        @raw_data["message"]
      end

      # Legacy compatibility
      alias message body

      def type
        @raw_data["type"]
      end

      def inbound?
        type == "inbound"
      end

      def unsubscribe?
        type == "unsubscribe"
      end

      def received_at
        return nil unless @raw_data["received_at"]

        Time.parse(@raw_data["received_at"])
      rescue ArgumentError, TypeError
        nil
      end

      def unicode?
        @raw_data["unicode"] == true
      end

      def to_h
        @raw_data
      end
    end

    # Response for status webhook updates
    class StatusUpdate
      attr_reader :raw_data

      def initialize(data)
        @raw_data = data
      end

      def message_id
        @raw_data["message_id"]
      end

      def custom_ref
        @raw_data["custom_ref"]
      end

      def to
        @raw_data["to"]
      end

      def sender
        @raw_data["sender"]
      end

      def body
        @raw_data["message"]
      end

      # Legacy compatibility
      alias message body

      def status
        @raw_data["status"]
      end

      def delivered?
        status == "delivered"
      end

      def failed?
        status == "failed"
      end

      def received_at
        return nil unless @raw_data["received_at"]

        Time.parse(@raw_data["received_at"])
      rescue ArgumentError, TypeError
        nil
      end

      def to_h
        @raw_data
      end
    end

    # Response for inbound messages polling (type=inbound)
    # API returns {"error": "No inbound or unsubscribe messages found."} when empty
    # API returns array of message objects when messages exist: [{"to": "...", "message": "...", ...}]
    class InboundMessagesResponse < BaseResponse
      def success?
        # Success if we get an array (even empty) or an error object indicating no messages
        @raw_response.is_a?(Array) || @raw_response["error"]&.include?("No inbound")
      end

      def messages
        # API returns direct array when messages exist, or error object when empty
        @messages ||= if @raw_response.is_a?(Array)
                        @raw_response.map { |m| InboundMessage.new(m) }
                      else
                        []
                      end
      end

      def total_count
        messages.count
      end

      def each_message(&block)
        messages.each(&block)
      end

      def empty?
        messages.empty?
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
