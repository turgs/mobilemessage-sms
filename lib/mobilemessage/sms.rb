# frozen_string_literal: true

require_relative "sms/version"
require_relative "sms/configuration"
require_relative "sms/errors"
require_relative "sms/http_client"
require_relative "sms/responses"
require_relative "sms/client"

module MobileMessage
  module SMS
    class << self
      # Create a new SMS client with enhanced responses (default)
      def client(username: nil, password: nil, **options)
        Client.new(username: username, password: password, **options)
      end

      # Create a client with enhanced response format
      def enhanced(username: nil, password: nil, **options)
        options[:response_format] = :enhanced
        client(username: username, password: password, **options)
      end

      # Create a client with raw response format (for compatibility)
      def raw(username: nil, password: nil, **options)
        options[:response_format] = :raw
        client(username: username, password: password, **options)
      end

      # Configure the gem with a block
      def configure
        config = Configuration.new
        yield config if block_given?
        config
      end
    end
  end
end
