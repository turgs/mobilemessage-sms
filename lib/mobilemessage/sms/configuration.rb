# frozen_string_literal: true

module MobileMessage
  module SMS
    # Configuration for MobileMessage SMS client
    class Configuration
      attr_accessor :username, :password, :default_from, :response_format,
                    :open_timeout, :read_timeout, :auto_retry, :max_retries,
                    :retry_delay, :sandbox_mode

      def initialize
        @username = nil
        @password = nil
        @default_from = nil
        @response_format = :enhanced # :enhanced, :raw, or :both
        @open_timeout = 30
        @read_timeout = 60
        @auto_retry = true
        @max_retries = 3
        @retry_delay = 2 # Base delay for exponential backoff
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
