#!/usr/bin/env ruby
# frozen_string_literal: true

# Polling for inbound messages using GET /v1/messages?type=inbound
# Note: For production, webhooks are recommended for real-time delivery

require 'mobilemessage'

client = MobileMessage.enhanced_sms(
  username: ENV['MOBILE_MESSAGE_USERNAME'] || 'your-username',
  password: ENV['MOBILE_MESSAGE_PASSWORD'] || 'your-password',
  default_from: 'YourBrand'
)

puts "=" * 60
puts "Polling for Inbound Messages"
puts "=" * 60
puts "\nNote: Webhooks are recommended for production as they provide"
puts "real-time notifications without the overhead of polling.\n\n"

# Example 1: Simple polling
puts "Example 1: Checking for inbound messages"
response = client.get_messages

if response.success?
  if response.empty?
    puts "✓ No new inbound messages"
  else
    puts "✓ Found #{response.messages.count} inbound message(s)"
    
    response.each_message do |message|
      puts "\n  Message:"
      puts "    From: #{message.from}"
      puts "    To: #{message.to}"
      puts "    Message: #{message.body}"
      puts "    Type: #{message.type}" # "inbound" or "unsubscribe"
      puts "    Received: #{message.received_at}"
      
      if message.original_message_id
        puts "    Reply to: #{message.original_message_id}"
        puts "    Original ref: #{message.original_custom_ref}"
      end
    end
  end
else
  puts "✗ Failed to retrieve messages: #{response.error_message}"
end

# Example 2: Polling with custom parameters
puts "\nExample 2: Polling with pagination"
response = client.get_messages(page: 1, per_page: 50)
puts "  Retrieved: #{response.messages.count} messages"

# Example 3: Polling loop (for demonstration)
puts "\nExample 3: Continuous polling (3 iterations)"
puts "  In production, run this as a background job/daemon\n"

3.times do |i|
  puts "  Poll #{i + 1}:"
  
  begin
    response = client.get_messages
    
    if response.success?
      if response.empty?
        puts "    No new messages"
      else
        puts "    Found #{response.messages.count} message(s)"
        response.each_message do |msg|
          puts "    - #{msg.from}: #{msg.body[0..50]}..."
        end
      end
    else
      puts "    ✗ Error: #{response.error_message}"
    end
  rescue MobileMessage::SMS::Error => e
    puts "    ✗ Exception: #{e.message}"
  end
  
  sleep 2 unless i == 2  # Don't sleep on last iteration
end

puts "\n" + "=" * 60
puts "Production Polling vs Webhooks Comparison"
puts "=" * 60
puts <<~INFO
  
  **Polling (GET /v1/messages?type=inbound):**
  ✓ Simple to implement
  ✓ No external endpoint needed
  ✗ Delayed notifications (depends on polling interval)
  ✗ Increased API usage
  ✗ Less efficient
  
  **Webhooks (Recommended):**
  ✓ Real-time notifications
  ✓ No polling overhead
  ✓ More efficient
  ✓ Scales better
  ✗ Requires public endpoint
  ✗ More complex setup
  
  For production systems, configure webhooks at:
  https://mobilemessage.com.au (Account Settings > Webhooks)
  
  See webhook_handler.rb for webhook implementation examples.

INFO

puts "\nDone!"
