#!/usr/bin/env ruby
# frozen_string_literal: true

# Basic usage example for mobilemessage-sms gem

require 'mobilemessage'

# Initialize client with your credentials
client = MobileMessage.enhanced_sms(
  username: ENV['MOBILE_MESSAGE_USERNAME'] || 'your-username',
  password: ENV['MOBILE_MESSAGE_PASSWORD'] || 'your-password',
  default_from: 'YourBrand'
)

# Example 1: Send a simple SMS
puts "Example 1: Sending a simple SMS"
response = client.send_sms(
  to: '0412345678',
  message: 'Hello from Mobile Message!',
  custom_ref: 'example_001'
)

if response.success?
  puts "✓ Message sent successfully!"
  puts "  Message ID: #{response.first_message_id}"
  puts "  Status: #{response.messages.first['status']}"
  puts "  Cost: #{response.total_cost} credits"
else
  puts "✗ Failed to send message"
  puts "  Error: #{response.error_message}"
end

# Example 2: Send with chainable error handling
puts "\nExample 2: Using chainable operations"
client.send_sms(to: '0412345678', message: 'Test message')
  .on_success { |r| puts "✓ Sent! ID: #{r.first_message_id}" }
  .on_error { |r| puts "✗ Failed: #{r.error_message}" }

# Example 3: Check account balance
puts "\nExample 3: Checking account balance"
balance = client.get_balance

if balance.success?
  puts "✓ Account balance retrieved"
  puts "  Balance: #{balance.formatted_balance}"
  
  if balance.low_balance?(threshold: 20)
    puts "  ⚠️  Warning: Low balance!"
  end
else
  puts "✗ Failed to get balance"
end

# Example 4: Get message status
puts "\nExample 4: Getting message status"
# Replace with actual message ID
message_id = response.first_message_id if response.success?

if message_id
  status_response = client.get_message_status(message_id: message_id)
  
  if status_response.success?
    puts "✓ Message status retrieved"
    puts "  Status: #{status_response.status}"
    puts "  Delivered: #{status_response.delivered? ? 'Yes' : 'No'}"
    puts "  Cost: #{status_response.cost} credits"
  end
end

# Example 5: Get message status by custom reference
puts "\nExample 5: Getting message by custom reference"
status_response = client.get_message_status(custom_ref: 'example_001')

if status_response.success?
  puts "✓ Message found by custom reference"
  puts "  Messages found: #{status_response.results.count}"
  status_response.results.each do |msg|
    puts "  - #{msg['message_id']}: #{msg['status']}"
  end
end

# Example 6: Error handling
puts "\nExample 6: Comprehensive error handling"
begin
  client.send_sms(to: 'invalid-number', message: 'Test', sender: 'Test')
rescue MobileMessage::SMS::AuthenticationError => e
  puts "🔑 Authentication failed: #{e.message}"
rescue MobileMessage::SMS::InvalidRequestError => e
  puts "📝 Invalid request: #{e.message}"
rescue MobileMessage::SMS::RateLimitError => e
  puts "⏰ Rate limited. Retry after #{e.suggested_retry_delay}s"
rescue MobileMessage::SMS::Error => e
  puts "❌ Error: #{e.message}"
end

puts "\nDone!"
