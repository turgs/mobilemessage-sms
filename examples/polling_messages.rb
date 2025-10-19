#!/usr/bin/env ruby
# frozen_string_literal: true

# NOTE: The Mobile Message API does not support polling for received messages.
# This example demonstrates why webhooks should be used instead.
#
# Configure webhooks in your Mobile Message account settings at:
# https://mobilemessage.com.au
#
# For webhook examples, see webhook_handler.rb

require 'mobilemessage'

client = MobileMessage.enhanced_sms(
  username: ENV['MOBILE_MESSAGE_USERNAME'] || 'your-username',
  password: ENV['MOBILE_MESSAGE_PASSWORD'] || 'your-password',
  default_from: 'YourBrand'
)

puts "=" * 60
puts "Message Polling (NOT SUPPORTED)"
puts "=" * 60
puts "\nThe Mobile Message API does not provide a polling endpoint for"
puts "received messages. Instead, you must configure webhooks."
puts "\nAttempting to poll will result in an error:\n\n"

begin
  response = client.get_messages
rescue NotImplementedError => e
  puts "✗ Error: #{e.message}"
end

puts "\n" + "=" * 60
puts "Alternative: Use Webhooks (RECOMMENDED)"
puts "=" * 60
puts <<~INFO
  
  To receive inbound SMS messages and delivery receipts in real-time:
  
  1. Configure webhook URLs in your Mobile Message account settings:
     - Inbound URL: Receives SMS replies and unsubscribe requests
     - Status URL: Receives delivery status updates
  
  2. Set up webhook endpoints in your application:
     
     # Example Rails controller
     class WebhooksController < ApplicationController
       skip_before_action :verify_authenticity_token
       
       def receive_sms
         webhook_data = client.parse_webhook(request.body.read)
         
         case webhook_data
         when MobileMessage::SMS::InboundMessage
           # Handle inbound SMS
           process_message(webhook_data)
         when MobileMessage::SMS::StatusUpdate
           # Handle delivery status
           update_status(webhook_data)
         end
         
         render plain: 'OK', status: :ok
       end
     end
  
  3. See webhook_handler.rb for a complete working example.
  
  Benefits of webhooks over polling:
  - Real-time notifications (instant delivery)
  - No API rate limits for receiving messages
  - More efficient (no repeated polling requests)
  - Lower latency
  - No missed messages
  - Scalable architecture

INFO

puts "\nFor a complete webhook example, run:"
puts "  ruby examples/webhook_handler.rb"
puts "\nDone!"
