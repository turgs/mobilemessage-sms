# Mobile Message SMS

> A comprehensive Ruby gem for the [Mobile Message API](https://mobilemessage.com.au), providing full SMS functionality with enhanced developer experience.

A Ruby gem for the Mobile Message API focused on SMS sending, receiving, and account management. Provides an enhanced developer experience with smart response objects while maintaining full access to the official Mobile Message API.

[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.0.0-ruby.svg)](https://www.ruby-lang.org/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE.txt)

## Features

### Core SMS Operations
- **Send SMS**: Individual messages with enhanced response objects
- **Bulk SMS**: Send to multiple recipients efficiently
- **Message Status**: Check delivery status and get message details
- **Account Balance**: Check account balance with low-balance detection
- **Inbound Messages**: Retrieve received SMS messages via polling
- **Webhook Support**: Parse and verify webhook payloads for real-time message delivery
- **Message Tracking**: Track messages until delivered with timeout support

### Enhanced Developer Experience
- **Smart Response Objects**: Convenient methods like `.success?`, `.message_id`, `.delivered?`
- **Chainable Operations**: `.on_success` and `.on_error` for clean error handling
- **Automatic Retry**: Built-in retry logic for rate limits and server errors
- **Flexible Configuration**: Custom retry settings, timeouts, and more
- **Sandbox Mode**: Safe testing without real API calls
- **Comprehensive Error Handling**: Specific error types with detailed information

### Configuration Options
- **Enhanced Responses**: Rich response objects with convenience methods (default)
- **Raw Responses**: Direct API responses for maximum compatibility
- **Response Format Options**: Choose between `:enhanced`, `:raw`, or `:both`
- **Sandbox Mode**: Test integration without consuming credits

## Quick Start

### Installation

Add to your Gemfile:

```ruby
gem 'mobilemessage-sms'
```

Then run:
```bash
bundle install
```

Or install directly:
```bash
gem install mobilemessage-sms
```

### Basic Usage

```ruby
require 'mobilemessage'

# Create client with enhanced responses (default behavior)
client = MobileMessage.enhanced_sms(
  username: 'your-api-username',
  password: 'your-api-password',
  default_from: 'YourBrand'
)

# Send a message with smart response handling
response = client.send_sms(
  to: '+61400000000',
  body: 'Hello from Mobile Message!'
)

# Clean, readable response handling
if response.success?
  puts "Message sent! ID: #{response.first_message_id}"
  puts "Status: #{response.messages.first['status']}"
else
  puts "Failed: #{response.error_message}"
end

# Chainable operations for elegant error handling
client.send_sms(to: '+61400000000', body: 'Hello!')
  .on_success { |r| puts "Sent! ID: #{r.first_message_id}" }
  .on_error { |r| puts "Failed: #{r.error_message}" }
```

## Complete API Reference

### Client Initialization

```ruby
# Enhanced response mode (recommended)
client = MobileMessage.enhanced_sms(
  username: 'your-username',
  password: 'your-password',
  default_from: 'YourBrand',
  sandbox_mode: false  # Set to true for testing
)

# Raw response mode (for compatibility)
client = MobileMessage.raw_sms(
  username: 'your-username',
  password: 'your-password'
)

# Custom configuration
client = MobileMessage::SMS::Client.new(
  username: 'your-username',
  password: 'your-password',
  default_from: 'YourBrand',
  response_format: :enhanced,  # :enhanced, :raw, or :both
  open_timeout: 30,
  read_timeout: 60,
  auto_retry: true,
  max_retries: 3,
  retry_delay: 2,
  sandbox_mode: false
)
```

### Sending SMS

#### Single Message

```ruby
# Basic send
response = client.send_sms(
  to: '+61400000000',
  body: 'Your message text',
  from: 'YourBrand'  # Optional if default_from is set
)

# With Unicode support (for emojis and special characters)
response = client.send_sms(
  to: '+61400000000',
  body: 'Hello! 👋 😊',
  unicode: true
)

# Check response
if response.success?
  puts "Message ID: #{response.first_message_id}"
  puts "Sent count: #{response.sent_count}"
  puts "All successful: #{response.all_successful?}"
end
```

#### Bulk Messages

```ruby
# Send different messages to different recipients
messages = [
  { to: '+61400000001', body: 'Hello Alice!', from: 'MyApp' },
  { to: '+61400000002', body: 'Hello Bob!', from: 'MyApp' },
  { to: '+61400000003', body: 'Hello Charlie!', from: 'MyApp', unicode: true }
]

response = client.send_bulk(messages: messages)

puts "Sent: #{response.sent_count}"
puts "Failed: #{response.failed_count}"
puts "All successful: #{response.all_successful?}"

# Iterate through individual message results
response.each_message do |message|
  puts "#{message['to']}: #{message['status']}"
end
```

#### Broadcast (Same message to multiple recipients)

```ruby
# Send same message to multiple numbers
response = client.broadcast(
  to_numbers: ['+61400000001', '+61400000002', '+61400000003'],
  body: 'Important announcement!',
  from: 'YourBrand'
)

puts "Broadcast sent to #{response.messages.count} recipients"
```

### Message Status and Tracking

```ruby
# Get message status
response = client.get_message_status(message_id: 'msg_12345')

if response.delivered?
  puts "Message delivered at: #{response.delivery_timestamp}"
elsif response.pending?
  puts "Message is pending"
elsif response.failed?
  puts "Message failed"
end

# Track message until delivered or failed
response = client.track_delivery(
  message_id: 'msg_12345',
  timeout: 300,       # 5 minutes
  check_interval: 30  # Check every 30 seconds
)

puts "Final status: #{response.status}"
```

### Account Balance

```ruby
response = client.get_balance

puts "Balance: #{response.formatted_balance}"
puts "Account: #{response.account_name}"

if response.low_balance?(threshold: 20)
  puts "⚠️  Your balance is low!"
end

# Also available as alias
balance = client.balance
```

### Receiving Messages (Polling)

```ruby
# Get received messages
response = client.get_messages(page: 1, per_page: 100)

puts "Page: #{response.page}/#{response.total_pages}"
puts "Total messages: #{response.total_count}"

# Iterate through messages
response.each_message do |message|
  puts "From: #{message.from}"
  puts "Body: #{message.body}"
  puts "Received: #{message.received_at}"
  puts "Unicode: #{message.unicode?}"
end

# Get only unread messages
response = client.get_messages(unread_only: true)

# Alternative aliases
response = client.received_messages
response = client.inbound_messages
```

### Webhook Handling

```ruby
# In your webhook endpoint (e.g., Rails controller)
def webhook
  payload = request.body.read
  
  # Parse webhook payload
  message = client.parse_webhook(payload)
  
  puts "Received from: #{message.from}"
  puts "Message: #{message.body}"
  puts "Received at: #{message.received_at}"
  
  # Verify webhook signature (if provided by Mobile Message)
  signature = request.headers['X-Signature']
  secret = ENV['WEBHOOK_SECRET']
  
  if client.verify_webhook_signature(
    payload: payload,
    signature: signature,
    secret: secret
  )
    # Process the message
    process_inbound_sms(message)
  else
    render status: :unauthorized
  end
end
```

## Response Objects

### SendSmsResponse

```ruby
response.success?           # Boolean: API call successful
response.error?             # Boolean: API call failed
response.messages           # Array: All message details
response.message_ids        # Array: All message IDs
response.first_message_id   # String: First message ID
response.sent_count         # Integer: Successfully sent messages
response.failed_count       # Integer: Failed messages
response.all_successful?    # Boolean: All messages sent
response.has_failures?      # Boolean: Any messages failed
response.each_message { |msg| ... }  # Iterator
response.error_message      # String: Error message if failed
response.error_code         # String: Error code if failed
```

### MessageStatusResponse

```ruby
response.message_id         # String: Message ID
response.status             # String: Current status
response.to                 # String: Recipient number
response.from               # String: Sender ID
response.body               # String: Message content
response.delivered?         # Boolean: Message delivered
response.pending?           # Boolean: Message pending
response.failed?            # Boolean: Message failed
response.delivery_timestamp # Time: When delivered
```

### BalanceResponse

```ruby
response.balance            # Float: Account balance
response.currency           # String: Currency code (e.g., "AUD")
response.account_name       # String: Account name
response.low_balance?(threshold)  # Boolean: Balance below threshold
response.formatted_balance  # String: Formatted balance with currency
```

### InboundMessage

```ruby
message.message_id          # String: Message ID
message.from                # String: Sender number
message.to                  # String: Recipient number
message.body                # String: Message content
message.received_at         # Time: When received
message.unicode?            # Boolean: Unicode message
```

### MessagesListResponse

```ruby
response.messages           # Array<InboundMessage>: Message objects
response.total_count        # Integer: Total message count
response.page               # Integer: Current page
response.per_page           # Integer: Messages per page
response.total_pages        # Integer: Total pages
response.has_more?          # Boolean: More pages available
response.each_message { |msg| ... }  # Iterator
```

### Chainable Operations

All enhanced response objects support chainable operations:

```ruby
client.send_sms(to: number, body: text)
  .on_success { |response| log_success(response.first_message_id) }
  .on_error { |response| log_error(response.error_message) }

client.broadcast(to_numbers: numbers, body: text)
  .on_success { |r| puts "Sent to #{r.sent_count} recipients" }
  .on_error { |r| puts "Broadcast failed: #{r.error_message}" }
```

## Error Handling

### Enhanced Error Handling (Recommended)

```ruby
begin
  response = client.send_sms(to: '+61400000000', body: 'Hello!')
rescue MobileMessage::SMS::AuthenticationError => e
  puts "🔑 Authentication failed: #{e.message}"
rescue MobileMessage::SMS::InsufficientCreditsError => e
  puts "💳 Insufficient credits: #{e.message}"
rescue MobileMessage::SMS::RateLimitError => e
  puts "⏰ Rate limited. Retry after #{e.suggested_retry_delay}s"
rescue MobileMessage::SMS::InvalidRequestError => e
  puts "📝 Invalid request: #{e.message}"
rescue MobileMessage::SMS::ServerError => e
  puts "🔧 Server error (#{e.status_code}): #{e.message}"
rescue MobileMessage::SMS::NetworkError => e
  puts "🌐 Network error: #{e.message}"
rescue MobileMessage::SMS::ApiError => e
  puts "❌ API error: #{e.message}"
  
  # Enhanced error detection
  if e.authentication_error?
    puts "Authentication problem"
  elsif e.rate_limited?
    puts "Rate limit - retry after #{e.suggested_retry_delay}s"
  elsif e.retryable?
    puts "This error is retryable"
  end
end
```

### Available Error Classes

- `MobileMessage::SMS::Error` - Base error class
- `MobileMessage::SMS::AuthenticationError` - Authentication failed (401)
- `MobileMessage::SMS::InvalidRequestError` - Invalid request (400)
- `MobileMessage::SMS::InsufficientCreditsError` - Not enough credits
- `MobileMessage::SMS::RateLimitError` - Rate limit exceeded (429)
- `MobileMessage::SMS::ServerError` - Server error (5xx)
- `MobileMessage::SMS::NetworkError` - Network/connection error
- `MobileMessage::SMS::ParseError` - JSON parsing error
- `MobileMessage::SMS::ApiError` - General API error with enhanced detection

### Automatic Retry

The client automatically retries rate limit and server errors:

```ruby
# Automatic retry is enabled by default
client = MobileMessage.enhanced_sms(
  username: 'user',
  password: 'pass',
  auto_retry: true,
  max_retries: 3,
  retry_delay: 2  # Base delay for exponential backoff
)

# Retry is automatic - this will retry up to 3 times
response = client.send_sms(to: '+61400000000', body: 'Test')
```

## Configuration

### Environment Variables

```bash
export MOBILE_MESSAGE_USERNAME="your-username"
export MOBILE_MESSAGE_PASSWORD="your-password"
export MOBILE_MESSAGE_DEFAULT_FROM="YourBrand"
export MOBILE_MESSAGE_SANDBOX="true"  # For testing
```

```ruby
# Use environment variables
client = MobileMessage.enhanced_sms(
  username: ENV['MOBILE_MESSAGE_USERNAME'],
  password: ENV['MOBILE_MESSAGE_PASSWORD'],
  default_from: ENV['MOBILE_MESSAGE_DEFAULT_FROM'],
  sandbox_mode: ENV['MOBILE_MESSAGE_SANDBOX'] == 'true'
)
```

### Advanced Configuration

```ruby
config = MobileMessage::SMS.configure do |c|
  c.username = 'your-username'
  c.password = 'your-password'
  c.default_from = 'YourBrand'
  c.response_format = :enhanced
  c.open_timeout = 30
  c.read_timeout = 60
  c.auto_retry = true
  c.max_retries = 3
  c.retry_delay = 2
  c.sandbox_mode = false
end

client = MobileMessage::SMS::Client.new(config: config)
```

## Testing

### Sandbox Mode

The gem includes comprehensive sandbox mode for testing without making real API calls:

```ruby
# Enable sandbox mode
client = MobileMessage.enhanced_sms(
  username: 'test-user',
  password: 'test-password',
  sandbox_mode: true,
  default_from: 'TestSender'
)

# All API calls return simulated responses
response = client.send_sms(to: '+61400000000', body: 'Test message')
puts response.success?  # => true
puts response.first_message_id  # => "sandbox_msg_..."

# Check balance in sandbox
balance = client.get_balance
puts balance.balance  # => 100.50
puts balance.account_name  # => "Sandbox Account"

# Get simulated received messages
messages = client.get_messages
puts messages.messages.count  # => 1
```

### Running Tests

```bash
# Install dependencies
bundle install

# Run all tests
bundle exec rake test

# Run specific test file
bundle exec ruby -Ilib -Itest test/test_client.rb

# Run specific test
bundle exec ruby -Ilib -Itest test/test_client.rb -n test_send_sms_success
```

## Migration Guide

### From Raw to Enhanced Responses

```ruby
# Before (raw responses)
if response['success']
  message_id = response['messages'][0]['message_id']
  puts "Sent! ID: #{message_id}"
end

# After (enhanced responses)
if response.success?
  puts "Sent! ID: #{response.first_message_id}"
end

# Enhanced responses still support hash access for compatibility
message_id = response['messages'][0]['message_id']  # Still works
message_id = response.dig('messages', 0, 'message_id')  # Still works
```

### Gradual Migration with :both Mode

```ruby
client = MobileMessage.enhanced_sms(
  username: 'user',
  password: 'pass',
  response_format: :both  # Enhanced objects with full raw access
)

response = client.send_sms(to: number, body: text)

# Use enhanced methods
puts response.success?
puts response.first_message_id

# Still access raw data when needed
puts response.raw_response['messages']
puts response['messages']  # Hash access still works
```

## API Documentation

This gem strictly aligns with the [Mobile Message API](https://api.mobilemessage.com.au/). All endpoints, request formats, and response structures match the official specification.

### Supported Endpoints

- `POST /v1/messages` - Send SMS messages (single or bulk)
- `GET /v1/messages/:id` - Get message status
- `GET /v1/messages/received` - Get received messages (polling)
- `GET /v1/account/balance` - Get account balance

### Authentication

The Mobile Message API uses HTTP Basic Authentication. Your username and password are encoded and sent with each request:

```ruby
# Authentication is handled automatically by the client
client = MobileMessage.enhanced_sms(
  username: 'your-api-username',
  password: 'your-api-password'
)
```

## Requirements

- Ruby 3.0 or higher
- No external dependencies (uses only Ruby standard library)

## Examples

Check the `examples/` directory for more usage examples:

- Basic SMS sending
- Bulk operations
- Webhook handling
- Error handling patterns
- Production-ready integrations

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/turgs/mobilemessage-sms.

1. Fork the repository
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

Please ensure all tests pass and add tests for new functionality.

## License

The gem is available as open source under the terms of the [MIT License](LICENSE.txt).

## Disclaimer

This is an unofficial gem. We are not affiliated with Mobile Message. Use at your own risk and always test thoroughly before production use.

## Support

For issues related to this gem, please open an issue on GitHub.

For Mobile Message API questions, please contact Mobile Message support at https://mobilemessage.com.au.
