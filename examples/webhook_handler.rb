#!/usr/bin/env ruby
# frozen_string_literal: true

# Example webhook handler for receiving SMS via webhooks
# This would typically be integrated into your web framework (Rails, Sinatra, etc.)

require 'mobilemessage'
require 'json'

# Initialize client
client = MobileMessage.enhanced_sms(
  username: ENV['MOBILE_MESSAGE_USERNAME'] || 'your-username',
  password: ENV['MOBILE_MESSAGE_PASSWORD'] || 'your-password'
)

# Example webhook payload (what Mobile Message would send)
sample_webhook_payload = {
  "message_id" => "msg_123456",
  "from" => "+61400000001",
  "to" => "+61400000000",
  "body" => "Hello! This is a test message.",
  "received_at" => Time.now.iso8601,
  "unicode" => false
}.to_json

puts "Processing webhook payload..."

# Parse the webhook
begin
  message = client.parse_webhook(sample_webhook_payload)
  
  puts "✓ Webhook parsed successfully"
  puts "  Message ID: #{message.message_id}"
  puts "  From: #{message.from}"
  puts "  To: #{message.to}"
  puts "  Body: #{message.body}"
  puts "  Received: #{message.received_at}"
  puts "  Unicode: #{message.unicode? ? 'Yes' : 'No'}"
  
  # Process the message based on content
  case message.body.downcase
  when /help/
    puts "\n→ Detected help request - would send help information"
  when /stop/, /unsubscribe/
    puts "\n→ Detected opt-out - would unsubscribe #{message.from}"
  when /info/
    puts "\n→ Detected info request - would send account info"
  else
    puts "\n→ General message - would process normally"
  end
  
rescue MobileMessage::SMS::ParseError => e
  puts "✗ Failed to parse webhook: #{e.message}"
end

# Example: Verify webhook signature (if Mobile Message provides this)
puts "\nExample: Webhook signature verification"
webhook_secret = ENV['MOBILE_MESSAGE_WEBHOOK_SECRET'] || 'your-webhook-secret'
mock_signature = 'some-signature-from-header'

is_valid = client.verify_webhook_signature(
  payload: sample_webhook_payload,
  signature: mock_signature,
  secret: webhook_secret
)

puts "  Signature valid: #{is_valid ? 'Yes' : 'No'}"

# Example Rails/Sinatra controller action
puts "\n" + "=" * 60
puts "Example integration with Rails/Sinatra:"
puts "=" * 60
puts <<~RUBY
  # In your Rails controller or Sinatra app:
  
  class WebhooksController < ApplicationController
    skip_before_action :verify_authenticity_token
    
    def receive_sms
      # Parse the webhook
      message = mobile_message_client.parse_webhook(request.body.read)
      
      # Verify signature if provided
      signature = request.headers['X-Signature']
      unless verify_signature(request.body.read, signature)
        return render status: :unauthorized
      end
      
      # Process the message
      process_inbound_sms(message)
      
      render json: { status: 'ok' }, status: :ok
    rescue MobileMessage::SMS::ParseError => e
      render json: { error: e.message }, status: :bad_request
    end
    
    private
    
    def mobile_message_client
      @client ||= MobileMessage.enhanced_sms(
        username: ENV['MOBILE_MESSAGE_USERNAME'],
        password: ENV['MOBILE_MESSAGE_PASSWORD']
      )
    end
    
    def verify_signature(payload, signature)
      return true unless signature # Optional if not using signatures
      
      mobile_message_client.verify_webhook_signature(
        payload: payload,
        signature: signature,
        secret: ENV['MOBILE_MESSAGE_WEBHOOK_SECRET']
      )
    end
    
    def process_inbound_sms(message)
      # Your business logic here
      InboundSmsJob.perform_later(
        from: message.from,
        body: message.body,
        message_id: message.message_id
      )
    end
  end
RUBY

puts "\nDone!"
