#!/usr/bin/env ruby
# frozen_string_literal: true

# Example webhook handler for receiving SMS and delivery status via webhooks
# This would typically be integrated into your web framework (Rails, Sinatra, etc.)

require 'mobilemessage'
require 'json'

# Initialize client
client = MobileMessage.enhanced_sms(
  username: ENV['MOBILE_MESSAGE_USERNAME'] || 'your-username',
  password: ENV['MOBILE_MESSAGE_PASSWORD'] || 'your-password'
)

# Example 1: Inbound SMS webhook payload (what Mobile Message would send)
puts "=" * 60
puts "Example 1: Processing Inbound SMS Webhook"
puts "=" * 60

sample_inbound_payload = {
  "to" => "61412345678",
  "message" => "Hello! This is a test message.",
  "sender" => "61412345699",
  "received_at" => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
  "type" => "inbound",
  "original_message_id" => "db6190e1-1ce8-4cdd-b871-244257d57abc",
  "original_custom_ref" => "tracking001"
}.to_json

# Parse the webhook
begin
  webhook_data = client.parse_webhook(sample_inbound_payload)
  
  if webhook_data.is_a?(MobileMessage::SMS::InboundMessage)
    puts "✓ Inbound message webhook parsed successfully"
    puts "  From: #{webhook_data.from}"
    puts "  To: #{webhook_data.to}"
    puts "  Message: #{webhook_data.body}"
    puts "  Type: #{webhook_data.type}"
    puts "  Received: #{webhook_data.received_at}"
    
    if webhook_data.original_message_id
      puts "  Original message ID: #{webhook_data.original_message_id}"
      puts "  Original custom ref: #{webhook_data.original_custom_ref}"
    end
    
    # Process the message based on type and content
    if webhook_data.unsubscribe?
      puts "\n→ Unsubscribe request - would remove #{webhook_data.from} from list"
    elsif webhook_data.body.downcase.include?('help')
      puts "\n→ Detected help request - would send help information"
    else
      puts "\n→ General message - would process normally"
    end
  end
  
rescue MobileMessage::SMS::ParseError => e
  puts "✗ Failed to parse webhook: #{e.message}"
end

# Example 2: Status Update webhook payload
puts "\n" + "=" * 60
puts "Example 2: Processing Status Update Webhook"
puts "=" * 60

sample_status_payload = {
  "to" => "61412345678",
  "message" => "Hello, this is message 1",
  "sender" => "Mobile MSG",
  "custom_ref" => "tracking001",
  "status" => "delivered",
  "message_id" => "044b035f-0396-4a47-8428-12d5273ab04a",
  "received_at" => Time.now.strftime("%Y-%m-%d %H:%M:%S")
}.to_json

begin
  webhook_data = client.parse_webhook(sample_status_payload)
  
  if webhook_data.is_a?(MobileMessage::SMS::StatusUpdate)
    puts "✓ Status update webhook parsed successfully"
    puts "  Message ID: #{webhook_data.message_id}"
    puts "  Custom Ref: #{webhook_data.custom_ref}"
    puts "  To: #{webhook_data.to}"
    puts "  Status: #{webhook_data.status}"
    puts "  Received: #{webhook_data.received_at}"
    
    if webhook_data.delivered?
      puts "\n→ Message was delivered successfully"
    elsif webhook_data.failed?
      puts "\n→ Message delivery failed - would retry or alert"
    end
  end
  
rescue MobileMessage::SMS::ParseError => e
  puts "✗ Failed to parse webhook: #{e.message}"
end

# Example 3: Verify webhook signature (if using HMAC verification)
puts "\n" + "=" * 60
puts "Example 3: Webhook Signature Verification"
puts "=" * 60

webhook_secret = ENV['MOBILE_MESSAGE_WEBHOOK_SECRET'] || 'your-webhook-secret'
mock_signature = 'some-signature-from-header'

is_valid = client.verify_webhook_signature(
  payload: sample_inbound_payload,
  signature: mock_signature,
  secret: webhook_secret
)

puts "  Signature valid: #{is_valid ? 'Yes' : 'No'}"

# Example Rails/Sinatra controller integration
puts "\n" + "=" * 60
puts "Example Rails/Sinatra Integration:"
puts "=" * 60
puts <<~RUBY
  # In your Rails controller or Sinatra app:
  
  class WebhooksController < ApplicationController
    skip_before_action :verify_authenticity_token
    
    # Inbound SMS webhook endpoint
    def receive_sms
      payload = request.body.read
      
      # Optional: Verify signature
      signature = request.headers['X-Signature']
      unless verify_signature(payload, signature)
        return render json: { error: 'Invalid signature' }, status: :unauthorized
      end
      
      # Parse the webhook
      webhook_data = mobile_message_client.parse_webhook(payload)
      
      case webhook_data
      when MobileMessage::SMS::InboundMessage
        process_inbound_sms(webhook_data)
      when MobileMessage::SMS::StatusUpdate
        process_status_update(webhook_data)
      end
      
      render plain: 'OK', status: :ok
    rescue MobileMessage::SMS::ParseError => e
      render json: { error: e.message }, status: :bad_request
    end
    
    # Delivery status webhook endpoint
    def delivery_status
      payload = request.body.read
      status = mobile_message_client.parse_webhook(payload)
      
      if status.is_a?(MobileMessage::SMS::StatusUpdate)
        update_message_status(status)
      end
      
      render plain: 'OK', status: :ok
    end
    
    private
    
    def mobile_message_client
      @client ||= MobileMessage.enhanced_sms(
        username: ENV['MOBILE_MESSAGE_USERNAME'],
        password: ENV['MOBILE_MESSAGE_PASSWORD']
      )
    end
    
    def verify_signature(payload, signature)
      return true unless signature
      
      mobile_message_client.verify_webhook_signature(
        payload: payload,
        signature: signature,
        secret: ENV['MOBILE_MESSAGE_WEBHOOK_SECRET']
      )
    end
    
    def process_inbound_sms(message)
      # Handle unsubscribe requests
      if message.unsubscribe?
        User.find_by(phone: message.from)&.update(sms_subscribed: false)
        return
      end
      
      # Queue job to process message
      InboundSmsJob.perform_later(
        from: message.from,
        to: message.to,
        body: message.body,
        type: message.type,
        original_message_id: message.original_message_id
      )
    end
    
    def process_status_update(status)
      # Update message status in database
      Message.find_by(message_id: status.message_id)&.update(
        delivery_status: status.status,
        delivered_at: status.received_at
      )
      
      # Trigger alerts if failed
      if status.failed?
        MessageFailureAlert.notify(status.message_id, status.custom_ref)
      end
    end
  end
  
  # Configure webhook URLs in your Mobile Message account settings:
  # - Inbound URL: https://yourapp.com/webhooks/sms/receive
  # - Status URL: https://yourapp.com/webhooks/sms/status
RUBY

puts "\nDone!"
