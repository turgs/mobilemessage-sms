#!/usr/bin/env ruby
# frozen_string_literal: true

# Example of polling for received messages

require 'mobilemessage'

client = MobileMessage.enhanced_sms(
  username: ENV['MOBILE_MESSAGE_USERNAME'] || 'your-username',
  password: ENV['MOBILE_MESSAGE_PASSWORD'] || 'your-password'
)

# Example 1: Get received messages (single page)
puts "Example 1: Getting received messages"
response = client.get_messages(page: 1, per_page: 10)

if response.success?
  puts "✓ Retrieved messages"
  puts "  Page: #{response.page}/#{response.total_pages}"
  puts "  Messages on this page: #{response.messages.count}"
  puts "  Total messages: #{response.total_count}"
  
  if response.messages.any?
    puts "\n  Messages:"
    response.each_message do |msg|
      puts "    • From: #{msg.from}"
      puts "      Body: #{msg.body}"
      puts "      Received: #{msg.received_at}"
      puts "      Unicode: #{msg.unicode? ? 'Yes' : 'No'}"
      puts ""
    end
  else
    puts "  No messages received"
  end
  
  if response.has_more?
    puts "  → More messages available on next page"
  end
end

# Example 2: Get all pages of messages
puts "\nExample 2: Getting all pages"
all_messages = []
page = 1

loop do
  response = client.get_messages(page: page, per_page: 100)
  
  break unless response.success?
  
  response.each_message do |msg|
    all_messages << msg
  end
  
  puts "  Fetched page #{page}/#{response.total_pages} (#{response.messages.count} messages)"
  
  break unless response.has_more?
  page += 1
end

puts "  Total messages retrieved: #{all_messages.count}"

# Example 3: Get only unread messages
puts "\nExample 3: Getting unread messages only"
response = client.get_messages(unread_only: true)

if response.success?
  puts "✓ Retrieved unread messages"
  puts "  Unread count: #{response.messages.count}"
end

# Example 4: Continuous polling (production pattern)
puts "\nExample 4: Continuous polling pattern"
puts "This would run continuously in production..."

def process_message(message)
  puts "  Processing: #{message.body[0..50]}..."
  # Your business logic here
  # e.g., store in database, trigger notifications, etc.
end

# Simulated polling loop (would run as a background job/daemon)
puts "\nSimulated polling (3 iterations):"
3.times do |i|
  puts "\n  Poll #{i + 1}:"
  
  begin
    response = client.get_messages(page: 1, per_page: 100)
    
    if response.success?
      if response.messages.any?
        puts "    Found #{response.messages.count} message(s)"
        response.each_message do |msg|
          process_message(msg)
        end
      else
        puts "    No new messages"
      end
    else
      puts "    ✗ Failed to fetch messages: #{response.error_message}"
    end
    
  rescue MobileMessage::SMS::Error => e
    puts "    ✗ Error: #{e.message}"
  end
  
  # In production, you would:
  # 1. Process each message
  # 2. Store message IDs of processed messages
  # 3. Mark them as read/delete them
  # 4. Sleep for your polling interval
  
  sleep 2 unless i == 2  # Don't sleep on last iteration
end

puts "\n" + "=" * 60
puts "Production polling pattern:"
puts "=" * 60
puts <<~RUBY
  # Background job or daemon process
  class SmsPollingService
    def initialize
      @client = MobileMessage.enhanced_sms(
        username: ENV['MOBILE_MESSAGE_USERNAME'],
        password: ENV['MOBILE_MESSAGE_PASSWORD']
      )
      @processed_ids = []
    end
    
    def run
      loop do
        poll_messages
        sleep 30  # Poll every 30 seconds
      end
    rescue => e
      logger.error "Polling error: \#{e.message}"
      sleep 60  # Wait longer on error
      retry
    end
    
    private
    
    def poll_messages
      response = @client.get_messages(page: 1, per_page: 100)
      return unless response.success?
      
      response.each_message do |message|
        # Skip if already processed
        next if @processed_ids.include?(message.message_id)
        
        begin
          # Process the message
          process_inbound_sms(message)
          
          # Track as processed
          @processed_ids << message.message_id
          
          # Cleanup old IDs (keep last 1000)
          @processed_ids.shift if @processed_ids.size > 1000
          
        rescue => e
          logger.error "Failed to process message \#{message.message_id}: \#{e.message}"
        end
      end
    end
    
    def process_inbound_sms(message)
      # Your business logic
      InboundSms.create!(
        message_id: message.message_id,
        from: message.from,
        to: message.to,
        body: message.body,
        received_at: message.received_at
      )
      
      # Trigger any automated responses
      AutoResponseService.process(message)
    end
  end
  
  # Start the service
  SmsPollingService.new.run
RUBY

puts "\nDone!"
