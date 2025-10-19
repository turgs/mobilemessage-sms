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
      def send_sms(to:, message:, sender: nil, unicode: false, custom_ref: nil)
        sender ||= @config.default_from
        raise ArgumentError, "sender (sender ID) is required" unless sender

        msg_data = {
          to: to,
          sender: sender,
          message: message
        }
        msg_data[:custom_ref] = custom_ref if custom_ref
        msg_data[:unicode] = unicode if unicode

        payload = { messages: [msg_data] }
        payload[:enable_unicode] = unicode if unicode

        response = with_retry { @http_client.post("messages", body: payload) }
        wrap_response(SendSmsResponse, response)
      end

      # Send multiple SMS messages in one request
      def send_bulk(messages:, enable_unicode: false)
        # Validate messages array
        raise ArgumentError, "messages must be an array" unless messages.is_a?(Array)
        raise ArgumentError, "messages array cannot be empty" if messages.empty?
        raise ArgumentError, "messages array cannot exceed 100 messages" if messages.length > 100

        # Ensure each message has required fields
        messages.each_with_index do |msg, idx|
          raise ArgumentError, "Message #{idx} must be a Hash" unless msg.is_a?(Hash)
          raise ArgumentError, "Message #{idx} missing 'to' field" unless msg[:to] || msg["to"]
          raise ArgumentError, "Message #{idx} missing 'message' field" unless msg[:message] || msg["message"]
        end

        # Format messages with default 'sender' if not specified
        formatted_messages = messages.map do |msg|
          msg_data = {
            to: msg[:to] || msg["to"],
            sender: msg[:sender] || msg["sender"] || @config.default_from,
            message: msg[:message] || msg["message"]
          }
          msg_data[:custom_ref] = msg[:custom_ref] || msg["custom_ref"] if msg[:custom_ref] || msg["custom_ref"]
          msg_data[:unicode] = msg[:unicode] || msg["unicode"] if msg[:unicode] || msg["unicode"]
          msg_data
        end

        # Check that all messages have 'sender'
        formatted_messages.each_with_index do |msg, idx|
          raise ArgumentError, "Message #{idx} missing 'sender' (sender ID)" unless msg[:sender]
        end

        payload = { messages: formatted_messages }
        payload[:enable_unicode] = enable_unicode if enable_unicode

        response = with_retry { @http_client.post("messages", body: payload) }
        wrap_response(SendSmsResponse, response)
      end

      # Convenient method to send same message to multiple recipients
      def broadcast(to_numbers:, message:, sender: nil, unicode: false, custom_ref: nil)
        sender ||= @config.default_from
        raise ArgumentError, "sender (sender ID) is required" unless sender
        raise ArgumentError, "to_numbers must be an array" unless to_numbers.is_a?(Array)
        raise ArgumentError, "to_numbers array cannot be empty" if to_numbers.empty?

        messages = to_numbers.map do |number|
          msg_data = {
            to: number,
            sender: sender,
            message: message
          }
          msg_data[:custom_ref] = custom_ref if custom_ref
          msg_data[:unicode] = unicode if unicode
          msg_data
        end

        send_bulk(messages: messages, enable_unicode: unicode)
      end

      # Get message status and delivery information
      # Can search by message_id or custom_ref (use % for wildcard searches)
      def get_message_status(message_id: nil, custom_ref: nil)
        raise ArgumentError, "Either message_id or custom_ref is required" unless message_id || custom_ref
        
        params = {}
        params[:message_id] = message_id if message_id
        params[:custom_ref] = custom_ref if custom_ref

        response = with_retry { @http_client.get("messages", params: params) }
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
        response = with_retry { @http_client.get("account") }
        wrap_response(BalanceResponse, response)
      end

      alias balance get_balance

      # Note: The Mobile Message API does not provide a polling endpoint for received messages.
      # Instead, configure webhooks in your account settings to receive real-time notifications
      # for inbound messages and delivery receipts.
      # This method is kept for backwards compatibility but will raise an error.
      def get_messages(page: 1, per_page: 100, unread_only: false)
        raise NotImplementedError, "The Mobile Message API does not support polling for received messages. " \
                                   "Please configure webhooks in your account settings at https://mobilemessage.com.au " \
                                   "to receive inbound messages and delivery receipts in real-time."
      end

      alias received_messages get_messages
      alias inbound_messages get_messages

      # Webhook handling helpers
      def parse_webhook(payload)
        # Payload can be a JSON string or already parsed hash
        data = payload.is_a?(String) ? JSON.parse(payload) : payload
        
        # Determine webhook type based on presence of fields
        if data["type"] # inbound message has type field
          InboundMessage.new(data)
        elsif data["status"] # status update has status field
          StatusUpdate.new(data)
        else
          # Default to inbound message for backwards compatibility
          InboundMessage.new(data)
        end
      rescue JSON::ParserError
        raise ParseError.new("Failed to parse webhook payload", response: payload)
      end

      # Verify webhook signature (if Mobile Message provides webhook signatures)
      def verify_webhook_signature(payload:, signature:, secret:)
        require "openssl"
        computed_signature = OpenSSL::HMAC.hexdigest("SHA256", secret, payload)
        # Use constant-time comparison to prevent timing attacks
        OpenSSL.fixed_length_secure_compare(computed_signature, signature)
      rescue ArgumentError
        # Signatures have different lengths
        false
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
        jitter = rand * Configuration::RETRY_JITTER_FACTOR * max_delay
        [max_delay + jitter, Configuration::MAX_RETRY_DELAY].min
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
          if method == :post
            generate_send_sms_response(body)
          elsif method == :get
            generate_message_status_response(params)
          else
            { "status" => "complete", "message" => "Sandbox response" }
          end
        when "account"
          generate_balance_response
        else
          { "status" => "complete", "message" => "Sandbox response" }
        end
      end

      def generate_send_sms_response(body)
        messages = body[:messages] || []
        response_messages = messages.map.with_index do |msg, idx|
          {
            "to" => msg[:to],
            "message" => msg[:message],
            "sender" => msg[:sender],
            "custom_ref" => msg[:custom_ref],
            "status" => "success",
            "cost" => 1,
            "message_id" => "sandbox_msg_#{Time.now.to_i}_#{idx}",
            "encoding" => msg[:unicode] ? "ucs2" : "gsm7"
          }
        end

        {
          "status" => "complete",
          "total_cost" => messages.length,
          "results" => response_messages
        }
      end

      def generate_message_status_response(params)
        message_id = params[:message_id] || "sandbox_msg_12345"
        {
          "status" => "complete",
          "results" => [
            {
              "to" => "+61400000000",
              "message" => "Test message",
              "sender" => "TestSender",
              "custom_ref" => params[:custom_ref] || "tracking001",
              "status" => "success",
              "cost" => 1,
              "message_id" => message_id,
              "requested_at" => Time.now.strftime("%Y-%m-%d %H:%M:%S")
            }
          ]
        }
      end

      def generate_balance_response
        {
          "status" => "complete",
          "credit_balance" => 1000
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
