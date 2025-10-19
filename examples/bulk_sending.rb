#!/usr/bin/env ruby
# frozen_string_literal: true

# Bulk SMS sending examples

require 'mobilemessage'

client = MobileMessage.enhanced_sms(
  username: ENV['MOBILE_MESSAGE_USERNAME'] || 'your-username',
  password: ENV['MOBILE_MESSAGE_PASSWORD'] || 'your-password',
  default_from: 'YourBrand'
)

# Example 1: Send different messages to different recipients
puts "Example 1: Personalized bulk messages"
messages = [
  { to: '0412345678', message: 'Hello Alice! Welcome to our service.', custom_ref: 'alice_welcome' },
  { to: '0412345679', message: 'Hello Bob! Your order is ready.', custom_ref: 'bob_order' },
  { to: '0412345680', message: 'Hello Charlie! Meeting at 3pm today.', custom_ref: 'charlie_meeting' }
]

response = client.send_bulk(messages: messages)

if response.success?
  puts "✓ Bulk send completed"
  puts "  Sent: #{response.sent_count}/#{response.messages.count}"
  puts "  Failed: #{response.failed_count}"
  puts "  Total cost: #{response.total_cost} credits"
  puts "  All successful: #{response.all_successful? ? 'Yes' : 'No'}"
  
  # Show individual results
  response.each_message do |msg|
    status_icon = msg['status'] == 'success' ? '✓' : '✗'
    puts "  #{status_icon} #{msg['to']}: #{msg['status']} (ID: #{msg['message_id']})"
  end
end

# Example 2: Broadcast same message to multiple recipients
puts "\nExample 2: Broadcasting to multiple recipients"
recipients = [
  '0412345678',
  '0412345679',
  '0412345680'
]

response = client.broadcast(
  to_numbers: recipients,
  message: 'URGENT: System maintenance scheduled for tonight at 10pm.',
  custom_ref: 'maint_broadcast_001'
)

if response.success?
  puts "✓ Broadcast sent to #{response.messages.count} recipients"
  puts "  Total cost: #{response.total_cost} credits"
  puts "  Success rate: #{(response.sent_count.to_f / response.messages.count * 100).round(1)}%"
  
  if response.has_failures?
    puts "  ⚠️  Some messages failed to send"
  end
end

# Example 3: Large batch with error handling
puts "\nExample 3: Sending to a large list"
# Simulate a large recipient list (API supports up to 100 messages per request)
large_list = (1..50).map { |i| "041234#{i.to_s.rjust(4, '0')}" }

begin
  response = client.broadcast(
    to_numbers: large_list,
    message: 'Flash sale! 50% off everything today only.',
    custom_ref: 'flash_sale_001'
  )
  
  puts "✓ Batch sent"
  puts "  Total recipients: #{large_list.count}"
  puts "  Successfully sent: #{response.sent_count}"
  puts "  Failed: #{response.failed_count}"
  puts "  Total cost: #{response.total_cost} credits"
  puts "  Success rate: #{(response.sent_count.to_f / response.messages.count * 100).round(1)}%"
  
rescue MobileMessage::SMS::InsufficientCreditsError => e
  puts "✗ Not enough credits to complete batch"
  puts "  Error: #{e.message}"
rescue MobileMessage::SMS::Error => e
  puts "✗ Batch failed: #{e.message}"
end

# Example 4: Unicode messages (emojis)
puts "\nExample 4: Sending Unicode messages"
messages = [
  { to: '0412345678', message: 'Hello! 👋 Welcome to our store 🎉', unicode: true },
  { to: '0412345679', message: 'Your order is ready for pickup! 📦', unicode: true }
]

response = client.send_bulk(messages: messages, enable_unicode: true)

if response.success?
  puts "✓ Unicode messages sent"
  response.each_message do |msg|
    puts "  - #{msg['to']}: #{msg['encoding']} encoding, cost: #{msg['cost']}"
  end
end

puts "\nDone!"
