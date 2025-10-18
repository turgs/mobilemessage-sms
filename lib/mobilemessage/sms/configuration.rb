# frozen_string_literal: true

module MobileMessage
  module SMS
    # Configuration for MobileMessage SMS client
    class Configuration
      # Default configuration values
      DEFAULT_OPEN_TIMEOUT = 30
      DEFAULT_READ_TIMEOUT = 60
      DEFAULT_MAX_RETRIES = 3
      DEFAULT_RETRY_DELAY = 2
      MAX_RETRY_DELAY = 60
      RETRY_JITTER_FACTOR = 0.3

      attr_accessor :username, :password, :default_from, :response_format,
                    :open_timeout, :read_timeout, :auto_retry, :max_retries,
                    :retry_delay, :sandbox_mode

      def initialize
        @username = nil
        @password = nil
        @default_from = nil
        @response_format = :enhanced # :enhanced, :raw, or :both
        @open_timeout = DEFAULT_OPEN_TIMEOUT
        @read_timeout = DEFAULT_READ_TIMEOUT
        @auto_retry = true
        @max_retries = DEFAULT_MAX_RETRIES
        @retry_delay = DEFAULT_RETRY_DELAY # Base delay for exponential backoff
        @sandbox_mode = false
      end

      def validate!
        raise ArgumentError, "username is required" if username.nil? || username.empty?
        raise ArgumentError, "password is required" if password.nil? || password.empty?

        unless %i[enhanced raw both].include?(response_format)
          raise ArgumentError, "response_format must be :enhanced, :raw, or :both"
        end

        true
      end

      def sandbox?
        @sandbox_mode == true
      end
    end
  end
end
