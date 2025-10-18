# frozen_string_literal: true

require "time"
require_relative "http_client"
require_relative "responses"
require_relative "errors"
require_relative "configuration"

module MobileMessage
  module SMS
    # Main client for interacting with Mobile Message API
    class Client
      attr_reader :config, :http_client

      def initialize(username: nil, password: nil, config: nil, **options)
        @config = config || Configuration.new
        @config.username = username if username
        @config.password = password if password

        # Apply any additional options
        options.each do |key, value|
          @config.send("#{key}=", value) if @config.respond_to?("#{key}=")
        end

        @config.validate!

        @http_client = if @config.sandbox?
                         SandboxHttpClient.new(username: @config.username, password: @config.password)
                       else
                         HttpClient.new(
                           username: @config.username,
                           password: @config.password,
                           open_timeout: @config.open_timeout,
                           read_timeout: @config.read_timeout
                         )
                       end
      end

      # Send a single SMS message
      def send_sms(to:, body:, from: nil, unicode: false)
        from ||= @config.default_from
        raise ArgumentError, "from (sender ID) is required" unless from

        payload = {
          messages: [
            {
              to: to,
              from: from,
              body: body,
              unicode: unicode
            }
          ]
        }

        response = with_retry { @http_client.post("messages", body: payload) }
        wrap_response(SendSmsResponse, response)
      end

      # Send multiple SMS messages in one request
      def send_bulk(messages:)
        # Validate messages array
        raise ArgumentError, "messages must be an array" unless messages.is_a?(Array)
        raise ArgumentError, "messages array cannot be empty" if messages.empty?

        # Ensure each message has required fields
        messages.each_with_index do |msg, idx|
          raise ArgumentError, "Message #{idx} must be a Hash" unless msg.is_a?(Hash)
          raise ArgumentError, "Message #{idx} missing 'to' field" unless msg[:to] || msg["to"]
          raise ArgumentError, "Message #{idx} missing 'body' field" unless msg[:body] || msg["body"]
        end

        # Format messages with default 'from' if not specified
        formatted_messages = messages.map do |msg|
          {
            to: msg[:to] || msg["to"],
            from: msg[:from] || msg["from"] || @config.default_from,
            body: msg[:body] || msg["body"],
            unicode: msg[:unicode] || msg["unicode"] || false
          }
        end

        # Check that all messages have 'from'
        formatted_messages.each_with_index do |msg, idx|
          raise ArgumentError, "Message #{idx} missing 'from' (sender ID)" unless msg[:from]
        end

        payload = { messages: formatted_messages }
        response = with_retry { @http_client.post("messages", body: payload) }
        wrap_response(SendSmsResponse, response)
      end

      # Convenient method to send same message to multiple recipients
      def broadcast(to_numbers:, body:, from: nil, unicode: false)
        from ||= @config.default_from
        raise ArgumentError, "from (sender ID) is required" unless from
        raise ArgumentError, "to_numbers must be an array" unless to_numbers.is_a?(Array)
        raise ArgumentError, "to_numbers array cannot be empty" if to_numbers.empty?

        messages = to_numbers.map do |number|
          {
            to: number,
            from: from,
            body: body,
            unicode: unicode
          }
        end

        send_bulk(messages: messages)
      end

      # Get message status and delivery information
      def get_message_status(message_id:)
        response = with_retry { @http_client.get("messages/#{message_id}") }
        wrap_response(MessageStatusResponse, response)
      end

      # Track message delivery until it reaches a final state
      def track_delivery(message_id:, timeout: 300, check_interval: 30)
        start_time = Time.now
        loop do
          status_response = get_message_status(message_id: message_id)
          
          # Return if in final state
          return status_response if status_response.delivered? || status_response.failed?

          # Check timeout
          if Time.now - start_time > timeout
            raise Error, "Tracking timeout after #{timeout} seconds"
          end

          sleep check_interval
        end
      end

      # Get account balance
      def get_balance
        response = with_retry { @http_client.get("account/balance") }
        wrap_response(BalanceResponse, response)
      end

      alias balance get_balance

      # Get received messages (polling)
      def get_messages(page: 1, per_page: 100, unread_only: false)
        params = { page: page, per_page: per_page }
        params[:unread] = true if unread_only

        response = with_retry { @http_client.get("messages/received", params: params) }
        wrap_response(MessagesListResponse, response)
      end

      alias received_messages get_messages
      alias inbound_messages get_messages

      # Webhook handling helpers
      def parse_webhook(payload)
        # Payload can be a JSON string or already parsed hash
        data = payload.is_a?(String) ? JSON.parse(payload) : payload
        InboundMessage.new(data)
      rescue JSON::ParserError
        raise ParseError.new("Failed to parse webhook payload", response: payload)
      end

      # Verify webhook signature (if Mobile Message provides webhook signatures)
      def verify_webhook_signature(payload:, signature:, secret:)
        require "openssl"
        computed_signature = OpenSSL::HMAC.hexdigest("SHA256", secret, payload)
        computed_signature == signature
      end

      private

      def with_retry(max_attempts: nil, &block)
        max_attempts ||= @config.auto_retry ? @config.max_retries : 1
        attempt = 0

        begin
          attempt += 1
          block.call
        rescue RateLimitError, ServerError
          if attempt < max_attempts
            delay = calculate_retry_delay(attempt)
            sleep delay
            retry
          else
            raise
          end
        end
      end

      def calculate_retry_delay(attempt)
        # Exponential backoff with jitter
        base_delay = @config.retry_delay
        max_delay = base_delay * (2**(attempt - 1))
        jitter = rand * 0.3 * max_delay # Add up to 30% jitter
        [max_delay + jitter, 60].min # Cap at 60 seconds
      end

      def wrap_response(response_class, raw_response)
        case @config.response_format
        when :enhanced
          response_class.new(raw_response)
        when :raw
          raw_response
        when :both
          response_class.new(raw_response)
        else
          raw_response
        end
      end
    end

    # Sandbox HTTP client for testing without real API calls
    class SandboxHttpClient
      attr_reader :username, :password

      def initialize(username:, password:)
        @username = username
        @password = password
      end

      def get(endpoint, params: {})
        generate_sandbox_response(endpoint, :get, params: params)
      end

      def post(endpoint, body: {})
        generate_sandbox_response(endpoint, :post, body: body)
      end

      def put(endpoint, body: {})
        generate_sandbox_response(endpoint, :put, body: body)
      end

      def delete(endpoint, params: {})
        generate_sandbox_response(endpoint, :delete, params: params)
      end

      private

      def generate_sandbox_response(endpoint, method, params: {}, body: {})
        case endpoint
        when "messages"
          generate_send_sms_response(body)
        when "messages/received"
          generate_received_messages_response(params)
        when "account/balance"
          generate_balance_response
        when /messages\/(.+)/
          generate_message_status_response(Regexp.last_match(1))
        else
          { "success" => true, "message" => "Sandbox response" }
        end
      end

      def generate_send_sms_response(body)
        messages = body[:messages] || []
        response_messages = messages.map.with_index do |msg, idx|
          {
            "message_id" => "sandbox_msg_#{Time.now.to_i}_#{idx}",
            "to" => msg[:to],
            "from" => msg[:from],
            "body" => msg[:body],
            "status" => "queued"
          }
        end

        {
          "success" => true,
          "messages" => response_messages
        }
      end

      def generate_message_status_response(message_id)
        {
          "success" => true,
          "message" => {
            "message_id" => message_id,
            "to" => "+61400000000",
            "from" => "TestSender",
            "body" => "Test message",
            "status" => "delivered",
            "delivered_at" => Time.now.iso8601
          }
        }
      end

      def generate_balance_response
        {
          "success" => true,
          "balance" => 100.50,
          "currency" => "AUD",
          "account_name" => "Sandbox Account"
        }
      end

      def generate_received_messages_response(params)
        messages_data = [
          {
            "message_id" => "sandbox_received_1",
            "from" => "+61400000001",
            "to" => "+61400000000",
            "body" => "Test received message",
            "received_at" => Time.now.iso8601,
            "unicode" => false
          }
        ]
        
        {
          "success" => true,
          "messages" => messages_data,
          "total_count" => messages_data.length,
          "page" => params[:page] || 1,
          "per_page" => params[:per_page] || 100
        }
      end
    end
  end
end
