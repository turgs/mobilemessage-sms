# frozen_string_literal: true

module MobileMessage
  module SMS
    # Base error class for all MobileMessage API errors
    class Error < StandardError; end

    # Raised when API authentication fails
    class AuthenticationError < Error
      attr_reader :response

      def initialize(message = "Authentication failed", response: nil)
        @response = response
        super(message)
      end
    end

    # Raised when API request is invalid or malformed
    class InvalidRequestError < Error
      attr_reader :response, :field

      def initialize(message = "Invalid request", response: nil, field: nil)
        @response = response
        @field = field
        super(message)
      end
    end

    # Raised when API rate limit is exceeded
    class RateLimitError < Error
      attr_reader :response, :retry_after

      def initialize(message = "Rate limit exceeded", response: nil, retry_after: nil)
        @response = response
        @retry_after = retry_after
        super(message)
      end

      def suggested_retry_delay
        @retry_after || 60
      end
    end

    # Raised when account has insufficient credits
    class InsufficientCreditsError < Error
      attr_reader :response, :required_credits, :available_credits

      def initialize(message = "Insufficient credits", response: nil, required: nil, available: nil)
        @response = response
        @required_credits = required
        @available_credits = available
        super(message)
      end
    end

    # Raised when API server returns an error
    class ServerError < Error
      attr_reader :response, :status_code

      def initialize(message = "Server error", response: nil, status_code: nil)
        @response = response
        @status_code = status_code
        super(message)
      end
    end

    # Raised when network request fails
    class NetworkError < Error
      attr_reader :original_error

      def initialize(message = "Network error", original_error: nil)
        @original_error = original_error
        super(message)
      end
    end

    # Raised when API response cannot be parsed
    class ParseError < Error
      attr_reader :response

      def initialize(message = "Failed to parse API response", response: nil)
        @response = response
        super(message)
      end
    end

    # General API error with enhanced error detection
    class ApiError < Error
      attr_reader :response, :error_code, :api_message, :status_code

      def initialize(message = "API error", response: nil, error_code: nil, status_code: nil)
        @response = response
        @error_code = error_code
        @status_code = status_code
        @api_message = message
        super(message)
      end

      # Error type detection methods
      def authentication_error?
        status_code == 401 || error_code&.to_s&.downcase&.include?("auth")
      end

      def invalid_number?
        error_code&.to_s&.downcase&.include?("number") ||
          api_message&.downcase&.include?("invalid number")
      end

      def insufficient_credits?
        error_code&.to_s&.downcase&.include?("credit") ||
          api_message&.downcase&.include?("insufficient credit")
      end

      def rate_limited?
        status_code == 429 || error_code&.to_s&.downcase&.include?("rate")
      end

      def server_error?
        status_code.to_i >= 500
      end

      def invalid_request?
        status_code == 400 || error_code&.to_s&.downcase&.include?("invalid")
      end

      def retryable?
        rate_limited? || server_error?
      end

      def suggested_retry_delay
        rate_limited? ? 60 : (server_error? ? 30 : 10)
      end
    end
  end
end
