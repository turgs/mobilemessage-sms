# frozen_string_literal: true

require_relative "mobilemessage/sms"

# Top-level module for MobileMessage gem
module MobileMessage
  class << self
    # Convenience method to create an SMS client
    def sms(username: nil, password: nil, **options)
      SMS.client(username: username, password: password, **options)
    end

    # Create enhanced SMS client
    def enhanced_sms(username: nil, password: nil, **options)
      SMS.enhanced(username: username, password: password, **options)
    end

    # Create raw SMS client
    def raw_sms(username: nil, password: nil, **options)
      SMS.raw(username: username, password: password, **options)
    end
  end
end
