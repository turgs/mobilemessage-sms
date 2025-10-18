# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require "base64"

module MobileMessage
  module SMS
    # Handles HTTP communication with Mobile Message API
    class HttpClient
      API_BASE_URL = "https://api.mobilemessage.com.au"
      API_VERSION = "v1"

      attr_reader :username, :password, :open_timeout, :read_timeout

      def initialize(username:, password:, open_timeout: 30, read_timeout: 60)
        @username = username
        @password = password
        @open_timeout = open_timeout
        @read_timeout = read_timeout
      end

      # Make a GET request
      def get(endpoint, params: {})
        uri = build_uri(endpoint, params)
        request = Net::HTTP::Get.new(uri)
        execute_request(uri, request)
      end

      # Make a POST request
      def post(endpoint, body: {})
        uri = build_uri(endpoint)
        request = Net::HTTP::Post.new(uri)
        request["Content-Type"] = "application/json"
        request.body = body.to_json
        execute_request(uri, request)
      end

      # Make a PUT request
      def put(endpoint, body: {})
        uri = build_uri(endpoint)
        request = Net::HTTP::Put.new(uri)
        request["Content-Type"] = "application/json"
        request.body = body.to_json
        execute_request(uri, request)
      end

      # Make a DELETE request
      def delete(endpoint, params: {})
        uri = build_uri(endpoint, params)
        request = Net::HTTP::Delete.new(uri)
        execute_request(uri, request)
      end

      private

      def build_uri(endpoint, params = {})
        path = "/#{API_VERSION}/#{endpoint.sub(%r{^/}, '')}"
        uri = URI.join(API_BASE_URL, path)

        unless params.empty?
          uri.query = URI.encode_www_form(params)
        end

        uri
      end

      def execute_request(uri, request)
        add_authentication(request)
        add_headers(request)

        begin
          response = Net::HTTP.start(
            uri.hostname,
            uri.port,
            use_ssl: uri.scheme == "https",
            open_timeout: @open_timeout,
            read_timeout: @read_timeout
          ) do |http|
            http.request(request)
          end

          handle_response(response)
        rescue AuthenticationError, RateLimitError, InsufficientCreditsError,
               InvalidRequestError, ServerError, ApiError, ParseError
          # Re-raise our own errors
          raise
        rescue Timeout::Error => e
          raise NetworkError.new("Request timeout", original_error: e)
        rescue SocketError, Errno::ECONNREFUSED => e
          raise NetworkError.new("Connection failed: #{e.message}", original_error: e)
        rescue StandardError => e
          raise NetworkError.new("Network error: #{e.message}", original_error: e)
        end
      end

      def add_authentication(request)
        credentials = Base64.strict_encode64("#{@username}:#{@password}")
        request["Authorization"] = "Basic #{credentials}"
      end

      def add_headers(request)
        request["Accept"] = "application/json"
        request["User-Agent"] = "mobilemessage-sms-ruby/#{MobileMessage::SMS::VERSION}"
      end

      def handle_response(response)
        case response.code.to_i
        when 200..299
          parse_json_response(response)
        when 401
          raise AuthenticationError.new(
            "Authentication failed: Invalid username or password",
            response: response
          )
        when 429
          retry_after = response["Retry-After"]&.to_i
          raise RateLimitError.new(
            "Rate limit exceeded",
            response: response,
            retry_after: retry_after
          )
        when 400..499
          error_data = parse_json_response(response) rescue {}
          error_message = error_data["error"]&.[]("message") || "Client error: #{response.code}"
          
          if error_message.downcase.include?("insufficient credit")
            raise InsufficientCreditsError.new(error_message, response: response)
          else
            raise InvalidRequestError.new(error_message, response: response)
          end
        when 500..599
          raise ServerError.new(
            "Server error: #{response.code}",
            response: response,
            status_code: response.code.to_i
          )
        else
          raise ApiError.new(
            "Unexpected response: #{response.code}",
            response: response,
            status_code: response.code.to_i
          )
        end
      end

      def parse_json_response(response)
        return {} if response.body.nil? || response.body.empty?

        JSON.parse(response.body)
      rescue JSON::ParserError
        raise ParseError.new("Failed to parse JSON response", response: response)
      end
    end
  end
end
