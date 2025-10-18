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
  { to: '+61400000001', body: 'Hello Alice! Welcome to our service.' },
  { to: '+61400000002', body: 'Hello Bob! Your order is ready.' },
  { to: '+61400000003', body: 'Hello Charlie! Meeting at 3pm today.' }
]

response = client.send_bulk(messages: messages)

if response.success?
  puts "✓ Bulk send completed"
  puts "  Sent: #{response.sent_count}/#{response.messages.count}"
  puts "  Failed: #{response.failed_count}"
  puts "  All successful: #{response.all_successful? ? 'Yes' : 'No'}"
  
  # Show individual results
  response.each_message do |msg|
    status_icon = msg['status'] == 'queued' ? '✓' : '✗'
    puts "  #{status_icon} #{msg['to']}: #{msg['status']}"
  end
end

# Example 2: Broadcast same message to multiple recipients
puts "\nExample 2: Broadcasting to multiple recipients"
recipients = [
  '+61400000001',
  '+61400000002',
  '+61400000003'
]

response = client.broadcast(
  to_numbers: recipients,
  body: 'URGENT: System maintenance scheduled for tonight at 10pm.'
)

if response.success?
  puts "✓ Broadcast sent to #{response.messages.count} recipients"
  puts "  Success rate: #{(response.sent_count.to_f / response.messages.count * 100).round(1)}%"
  
  if response.has_failures?
    puts "  ⚠️  Some messages failed to send"
  end
end

# Example 3: Large batch with error handling
puts "\nExample 3: Sending to a large list"
# Simulate a large recipient list
large_list = (1..50).map { |i| "+6140000#{i.to_s.rjust(4, '0')}" }

begin
  response = client.broadcast(
    to_numbers: large_list,
    body: 'Flash sale! 50% off everything today only.'
  )
  
  puts "✓ Batch sent"
  puts "  Total recipients: #{large_list.count}"
  puts "  Successfully sent: #{response.sent_count}"
  puts "  Failed: #{response.failed_count}"
  puts "  Success rate: #{(response.sent_count.to_f / response.messages.count * 100).round(1)}%"
  
rescue MobileMessage::SMS::InsufficientCreditsError => e
  puts "✗ Not enough credits to complete batch"
  puts "  Error: #{e.message}"
rescue MobileMessage::SMS::Error => e
  puts "✗ Batch failed: #{e.message}"
end

puts "\nDone!"
