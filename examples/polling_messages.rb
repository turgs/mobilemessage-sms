#!/usr/bin/env ruby
# frozen_string_literal: true

# Polling for inbound messages using GET /v1/messages?type=inbound
# Note: API only returns the MOST RECENT inbound message
# Messages don't disappear after being read
# For production, webhooks are recommended for real-time delivery

require 'mobilemessage'

client = MobileMessage.enhanced_sms(
  username: ENV['MOBILE_MESSAGE_USERNAME'] || 'your-username',
  password: ENV['MOBILE_MESSAGE_PASSWORD'] || 'your-password',
  default_from: 'YourBrand'
)

puts "=" * 60
puts "Polling for Inbound Messages"
puts "=" * 60
puts "\nIMPORTANT:"
puts "- API only returns the MOST RECENT inbound message"
puts "- Messages persist and don't disappear after being read"
puts "- Timestamps are in UTC"
puts "- Webhooks are recommended for production\n\n"

# Example 1: Simple polling
puts "Example 1: Checking for most recent inbound message"
response = client.get_messages

if response.success?
  if response.empty?
    puts "✓ No inbound messages"
  else
    message = response.messages.first
    puts "✓ Most recent inbound message:"
    puts "\n  From: #{message.from}"
    puts "  To: #{message.to}"
    puts "  Message: #{message.body}"
    puts "  Type: #{message.type}" # "inbound" or "unsubscribe"
    puts "  Received: #{message.received_at} (UTC)"
    
    if message.original_message_id
      puts "  Reply to: #{message.original_message_id}"
      puts "  Original ref: #{message.original_custom_ref}"
    end
  end
else
  puts "✗ Failed to retrieve messages: #{response.error_message}"
end

# Example 2: Polling loop (for demonstration)
puts "\nExample 2: Continuous polling (3 iterations)"
puts "  Note: API returns same message until a new one arrives\n"

last_message_id = nil

3.times do |i|
  puts "  Poll #{i + 1}:"
  
  begin
    response = client.get_messages
    
    if response.success?
      if response.empty?
        puts "    No messages"
      else
        msg = response.messages.first
        # Check if this is a new message or the same one
        if msg.message_id == last_message_id
          puts "    Same message as before"
        else
          puts "    New message from #{msg.from}: #{msg.body[0..50]}..."
          last_message_id = msg.message_id
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
  ✗ Only returns MOST RECENT message
  ✗ Delayed notifications (depends on polling interval)
  ✗ Increased API usage
  ✗ Less efficient
  ✗ Can miss messages if multiple arrive between polls
  
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
