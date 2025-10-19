# Mobile Message SMS

> A comprehensive Ruby gem for the [Mobile Message API](https://mobilemessage.com.au), providing full SMS functionality with enhanced developer experience.

A Ruby gem for the Mobile Message API focused on SMS sending, receiving, and account management. Provides an enhanced developer experience with smart response objects while maintaining full access to the official Mobile Message API.

[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.0.0-ruby.svg)](https://www.ruby-lang.org/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE.txt)

## Table of Contents

- [Features](#features)
- [Quick Start](#quick-start)
- [Complete API Reference](#complete-api-reference)
- [API Documentation](#api-documentation)
  - [Complete API Method Mapping](#complete-api-method-mapping)
  - [Method Details](#method-details)
  - [Supported Endpoints](#supported-endpoints)
  - [Authentication](#authentication)
- [Response Objects](#response-objects)
- [Error Handling](#error-handling)
- [Configuration](#configuration)
- [Testing](#testing)
- [Migration Guide](#migration-guide)
- [Performance Considerations](#performance-considerations)
- [Requirements](#requirements)
- [Examples](#examples)
- [Contributing](#contributing)
- [License](#license)

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
  to: '0412345678',
  message: 'Hello from Mobile Message!'
)

# Clean, readable response handling
if response.success?
  puts "Message sent! ID: #{response.first_message_id}"
  puts "Status: #{response.messages.first['status']}"
  puts "Cost: #{response.total_cost} credits"
else
  puts "Failed: #{response.error_message}"
end

# Chainable operations for elegant error handling
client.send_sms(to: '0412345678', message: 'Hello!')
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
  to: '0412345678',
  message: 'Your message text',
  sender: 'YourBrand'  # Optional if default_from is set
)

# With Unicode support (for emojis and special characters)
response = client.send_sms(
  to: '0412345678',
  message: 'Hello! 👋 😊',
  unicode: true
)

# With custom reference for tracking
response = client.send_sms(
  to: '0412345678',
  message: 'Order #12345 shipped',
  custom_ref: 'order_12345'
)

# Check response
if response.success?
  puts "Message ID: #{response.first_message_id}"
  puts "Sent count: #{response.sent_count}"
  puts "Total cost: #{response.total_cost} credits"
  puts "All successful: #{response.all_successful?}"
end
```

#### Bulk Messages

```ruby
# Send different messages to different recipients (up to 100 per request)
messages = [
  { to: '0412345678', message: 'Hello Alice!', sender: 'MyApp', custom_ref: 'alice_001' },
  { to: '0412345679', message: 'Hello Bob!', sender: 'MyApp', custom_ref: 'bob_001' },
  { to: '0412345680', message: 'Hello Charlie! 🎉', sender: 'MyApp', unicode: true }
]

response = client.send_bulk(messages: messages, enable_unicode: true)

puts "Sent: #{response.sent_count}"
puts "Failed: #{response.failed_count}"
puts "Total cost: #{response.total_cost} credits"
puts "All successful: #{response.all_successful?}"

# Iterate through individual message results
response.each_message do |msg|
  puts "#{msg['to']}: #{msg['status']} (ID: #{msg['message_id']})"
end
```

#### Broadcast (Same message to multiple recipients)

```ruby
# Send same message to multiple numbers
response = client.broadcast(
  to_numbers: ['0412345678', '0412345679', '0412345680'],
  message: 'Important announcement!',
  sender: 'YourBrand',
  custom_ref: 'announcement_001'
)

puts "Broadcast sent to #{response.messages.count} recipients"
puts "Total cost: #{response.total_cost} credits"
```

### Message Status and Tracking

```ruby
# Get message status by message_id
response = client.get_message_status(message_id: 'abcd1234-efgh-5678-ijkl-9876543210mn')

if response.delivered?
  puts "Message delivered!"
  puts "Requested at: #{response.requested_at}"
elsif response.pending?
  puts "Message is pending"
elsif response.failed?
  puts "Message failed"
end

# Get message status by custom_ref
response = client.get_message_status(custom_ref: 'tracking001')

# Use wildcard search with custom_ref
response = client.get_message_status(custom_ref: 'tracking%')

# Track message until delivered or failed
# Note: This method blocks the thread and polls the API.
# For production, use webhooks for real-time delivery notifications.
# Only suitable for tracking a single message at a time.
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

if response.low_balance?(threshold: 20)
  puts "⚠️  Your balance is low!"
end

# Also available as alias
balance = client.balance
puts "Credits remaining: #{balance.balance}"
```

### Receiving Messages

The Mobile Message API provides two ways to receive inbound SMS messages:

1. **Webhooks (Recommended)**: Real-time push notifications
2. **Polling**: Query the API for new messages using `type=inbound` parameter

#### Option 1: Webhooks (Recommended for Production)

Configure your webhook URLs at https://mobilemessage.com.au in your account settings:
- **Inbound URL**: For receiving SMS replies and unsubscribe requests
- **Status URL**: For delivery receipt notifications

```ruby
# In your webhook endpoint (e.g., Rails controller or Sinatra app)
def webhook_inbound
  payload = request.body.read
  
  # Parse inbound message webhook
  message = client.parse_webhook(payload)
  
  if message.is_a?(MobileMessage::SMS::InboundMessage)
    puts "Inbound message received"
    puts "From: #{message.from}"
    puts "To: #{message.to}"
    puts "Message: #{message.body}"
    puts "Type: #{message.type}" # "inbound" or "unsubscribe"
    puts "Received at: #{message.received_at}"
    
    if message.original_message_id
      puts "Reply to message: #{message.original_message_id}"
      puts "Original ref: #{message.original_custom_ref}"
    end
  end
  
  # Respond with 200 OK
  render plain: "OK", status: 200
end

def webhook_status
  payload = request.body.read
  
  # Parse status update webhook
  status = client.parse_webhook(payload)
  
  if status.is_a?(MobileMessage::SMS::StatusUpdate)
    puts "Status update received"
    puts "Message ID: #{status.message_id}"
    puts "Custom Ref: #{status.custom_ref}"
    puts "Status: #{status.status}" # "delivered" or "failed"
    puts "To: #{status.to}"
    
    if status.delivered?
      puts "Message was delivered!"
    elsif status.failed?
      puts "Message delivery failed"
    end
  end
  
  render plain: "OK", status: 200
end
```

#### Option 2: Polling (Alternative)

You can also poll for inbound messages using the `GET /v1/messages?type=inbound` endpoint:

```ruby
# Poll for inbound messages
response = client.get_messages

if response.success?
  if response.empty?
    puts "No new inbound messages"
  else
    puts "Found #{response.messages.count} inbound message(s)"
    
    response.each_message do |message|
      puts "From: #{message.from}"
      puts "To: #{message.to}"
      puts "Message: #{message.body}"
      puts "Type: #{message.type}" # "inbound" or "unsubscribe"
      puts "Received: #{message.received_at}"
    end
  end
end

# Polling with custom parameters
response = client.get_messages(page: 1, per_page: 50)

# Alternative method names
response = client.received_messages
response = client.inbound_messages
```

**Note:** Webhooks are recommended for production as they provide real-time notifications without the overhead of polling.

### Webhook Handling

```ruby
# In your webhook endpoint (e.g., Rails controller)
def webhook
  payload = request.body.read
  
  # Parse webhook payload (automatically detects inbound vs status)
  webhook_data = client.parse_webhook(payload)
  
  case webhook_data
  when MobileMessage::SMS::InboundMessage
    # Handle inbound SMS
    puts "Received from: #{webhook_data.from}"
    puts "Message: #{webhook_data.body}"
    puts "Type: #{webhook_data.type}" # "inbound" or "unsubscribe"
  when MobileMessage::SMS::StatusUpdate
    # Handle delivery status
    puts "Message #{webhook_data.message_id}: #{webhook_data.status}"
    puts "Custom Ref: #{webhook_data.custom_ref}"
  end
  
  # Verify webhook signature (if using HMAC verification)
  signature = request.headers['X-Signature']
  secret = ENV['WEBHOOK_SECRET']
  
  if client.verify_webhook_signature(
    payload: payload,
    signature: signature,
    secret: secret
  )
    # Process the webhook
    process_webhook(webhook_data)
    render plain: "OK", status: 200
  else
    render plain: "Unauthorized", status: 401
  end
end
```

## Response Objects

### SendSmsResponse

```ruby
response.success?           # Boolean: API call successful (status == "complete")
response.error?             # Boolean: API call failed
response.messages           # Array: All message details (from "results")
response.message_ids        # Array: All message IDs
response.first_message_id   # String: First message ID
response.sent_count         # Integer: Successfully sent messages
response.failed_count       # Integer: Failed messages
response.all_successful?    # Boolean: All messages sent
response.has_failures?      # Boolean: Any messages failed
response.total_cost         # Integer: Total cost in credits
response.each_message { |msg| ... }  # Iterator
response.error_message      # String: Error message if failed
response.error_code         # String: Error code if failed
```

### MessageStatusResponse

```ruby
response.message_id         # String: Message ID
response.status             # String: Current status
response.to                 # String: Recipient number
response.sender             # String: Sender ID
response.body               # String: Message content
response.custom_ref         # String: Your custom reference
response.cost               # Integer: Message cost in credits
response.delivered?         # Boolean: Message delivered
response.pending?           # Boolean: Message pending
response.failed?            # Boolean: Message failed
response.requested_at       # Time: When message was requested
```

### BalanceResponse

```ruby
response.balance            # Integer: Account credit balance
response.credit_balance     # Integer: Same as balance (alias)
response.currency           # String: Currency code ("AUD")
response.low_balance?(threshold)  # Boolean: Balance below threshold
response.formatted_balance  # String: Formatted balance ("1000 credits")
```

### InboundMessagesResponse (Polling)

```ruby
response.success?           # Boolean: API call successful
response.messages           # Array<InboundMessage>: Inbound message objects
response.total_count        # Integer: Number of messages
response.empty?             # Boolean: No messages found
response.each_message { |msg| ... }  # Iterator
```

### InboundMessage (Webhook Data)

```ruby
message.to                  # String: Recipient number (your number)
message.from                # String: Sender number
message.sender              # String: Same as from (alias)
message.body                # String: Message content
message.message             # String: Same as body (alias)
message.type                # String: "inbound" or "unsubscribe"
message.inbound?            # Boolean: Is inbound message
message.unsubscribe?        # Boolean: Is unsubscribe request
message.received_at         # Time: When received
message.original_message_id # String: Original outbound message ID (if reply)
message.original_custom_ref # String: Original custom ref (if reply)
```

### StatusUpdate (Webhook Data)

```ruby
status.message_id           # String: Message ID
status.custom_ref           # String: Your custom reference
status.to                   # String: Recipient number
status.sender               # String: Sender ID
status.body                 # String: Message content
status.message              # String: Same as body (alias)
status.status               # String: "delivered" or "failed"
status.delivered?           # Boolean: Message was delivered
status.failed?              # Boolean: Message failed
status.received_at          # Time: When status was received
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

This gem provides a Ruby interface for the [Mobile Message API](https://mobilemessage.com.au/api-documentation). All methods map directly to official API endpoints.

**Official Documentation:** [https://mobilemessage.com.au/api-documentation](https://mobilemessage.com.au/api-documentation)

### Complete API Method Mapping

This table shows every public method in this gem and how it maps to the official Mobile Message API:

| Gem Method | Mobile Message API Endpoint | Description | Official Docs |
|------------|----------------------------|-------------|---------------|
| **Client Initialization** |
| `MobileMessage.enhanced_sms()` | - | Creates client with enhanced response objects (recommended) | [API Docs](https://mobilemessage.com.au/api-documentation) |
| `MobileMessage.raw_sms()` | - | Creates client with raw API responses | [API Docs](https://mobilemessage.com.au/api-documentation) |
| `MobileMessage.sms()` | - | Creates client (alias for enhanced_sms) | [API Docs](https://mobilemessage.com.au/api-documentation) |
| **Sending Messages** |
| `client.send_sms(to:, message:, sender:, unicode:, custom_ref:)` | `POST /v1/messages` | Send single SMS message | [Send SMS](https://mobilemessage.com.au/api-documentation) |
| `client.send_bulk(messages:, enable_unicode:)` | `POST /v1/messages` | Send up to 100 SMS messages in one request | [Send SMS](https://mobilemessage.com.au/api-documentation) |
| `client.broadcast(to_numbers:, message:, sender:, unicode:, custom_ref:)` | `POST /v1/messages` | Send same message to multiple recipients | [Send SMS](https://mobilemessage.com.au/api-documentation) |
| **Message Status & Tracking** |
| `client.get_message_status(message_id:, custom_ref:)` | `GET /v1/messages?message_id=...` | Get delivery status for message(s) | [Lookup Messages](https://mobilemessage.com.au/api-documentation) |
| `client.track_delivery(message_id:, timeout:, check_interval:)` | `GET /v1/messages` (polling) | Poll message status until delivered or failed | [Lookup Messages](https://mobilemessage.com.au/api-documentation) |
| **Account Management** |
| `client.get_balance()` | `GET /v1/account` | Get current account credit balance | [Account Balance](https://mobilemessage.com.au/api-documentation) |
| `client.balance()` | `GET /v1/account` | Alias for get_balance() | [Account Balance](https://mobilemessage.com.au/api-documentation) |
| **Receiving Messages** |
| `client.get_messages(page:, per_page:)` | `GET /v1/messages?type=inbound` | Poll for inbound SMS messages | [Receive SMS](https://mobilemessage.com.au/api-documentation) |
| `client.received_messages()` | `GET /v1/messages?type=inbound` | Alias for get_messages() | [Receive SMS](https://mobilemessage.com.au/api-documentation) |
| `client.inbound_messages()` | `GET /v1/messages?type=inbound` | Alias for get_messages() | [Receive SMS](https://mobilemessage.com.au/api-documentation) |
| **Webhook Handling** |
| `client.parse_webhook(payload)` | - | Parse inbound or status webhook payload | [Webhooks](https://mobilemessage.com.au/api-documentation) |
| `client.verify_webhook_signature(payload:, signature:, secret:)` | - | Verify webhook signature for security | [Webhooks](https://mobilemessage.com.au/api-documentation) |

### Method Details

#### Client Initialization

```ruby
# Enhanced responses (recommended) - provides convenience methods like .success?, .first_message_id
client = MobileMessage.enhanced_sms(
  username: 'your-api-username',
  password: 'your-api-password',
  default_from: 'YourBrand',
  sandbox_mode: false
)

# Raw responses - returns plain hashes directly from API
client = MobileMessage.raw_sms(
  username: 'your-api-username',
  password: 'your-api-password'
)
```

**Maps to:** N/A (local initialization)  
**Official API Authentication:** HTTP Basic Auth (handled automatically)

---

#### send_sms(to:, message:, sender:, unicode:, custom_ref:)

Send a single SMS message.

```ruby
response = client.send_sms(
  to: '0412345678',         # Required: recipient phone number (local or international format)
  message: 'Your message',  # Required: message text
  sender: 'YourBrand',      # Optional: sender ID (uses default_from if not provided)
  unicode: false,           # Optional: enable for emojis/special characters
  custom_ref: 'ref_001'     # Optional: your custom reference for tracking
)
```

**Maps to:** `POST /v1/messages` with single message in array  
**API Request Format:**
```json
{
  "enable_unicode": true,
  "messages": [
    {
      "to": "0412345678",
      "sender": "YourBrand",
      "message": "Your message",
      "custom_ref": "ref_001",
      "unicode": true
    }
  ]
}
```

**API Response:**
```json
{
  "status": "complete",
  "total_cost": 1,
  "results": [
    {
      "to": "0412345678",
      "message": "Your message",
      "sender": "YourBrand",
      "custom_ref": "ref_001",
      "status": "success",
      "cost": 1,
      "message_id": "abcd1234-efgh-5678-ijkl-9876543210mn",
      "encoding": "gsm7"
    }
  ]
}
```

**Enhanced Response Methods:** `.success?`, `.first_message_id`, `.sent_count`, `.total_cost`, `.messages`

---

#### send_bulk(messages:, enable_unicode:)

Send multiple different messages in one API call (up to 100 messages).

```ruby
response = client.send_bulk(
  messages: [
    { to: '0412345678', message: 'Message 1', sender: 'Brand', custom_ref: 'ref1' },
    { to: '0412345679', message: 'Message 2 🎉', sender: 'Brand', unicode: true }
  ],
  enable_unicode: true  # Optional: global unicode setting
)
```

**Maps to:** `POST /v1/messages` with multiple messages  
**API Request Format:**
```json
{
  "enable_unicode": true,
  "messages": [
    { "to": "0412345678", "sender": "Brand", "message": "Message 1", "custom_ref": "ref1" },
    { "to": "0412345679", "sender": "Brand", "message": "Message 2 🎉", "unicode": true }
  ]
}
```

**Enhanced Response Methods:** `.success?`, `.sent_count`, `.failed_count`, `.total_cost`, `.all_successful?`, `.each_message`

---

#### broadcast(to_numbers:, message:, sender:, unicode:, custom_ref:)

Convenience method to send the same message to multiple recipients.

```ruby
response = client.broadcast(
  to_numbers: ['0412345678', '0412345679', '0412345680'],
  message: 'Same message for all',
  sender: 'YourBrand',
  custom_ref: 'broadcast_001'
)
```

**Maps to:** `POST /v1/messages` (internally converts to send_bulk format)  
**Enhanced Response Methods:** `.success?`, `.sent_count`, `.total_cost`, `.messages`

---

#### get_message_status(message_id:, custom_ref:)

Get delivery status and details for message(s). Search by message_id or custom_ref (use % for wildcard).

```ruby
# By message_id
response = client.get_message_status(message_id: 'abcd1234-efgh-5678-ijkl-9876543210mn')

# By custom_ref
response = client.get_message_status(custom_ref: 'tracking001')

# Wildcard search
response = client.get_message_status(custom_ref: 'tracking%')
```

**Maps to:** `GET /v1/messages?message_id=...` or `GET /v1/messages?custom_ref=...`  
**API Response Example:**
```json
{
  "status": "complete",
  "results": [
    {
      "to": "+61412345678",
      "message": "Hello, this is message 1",
      "sender": "CompanyABC",
      "custom_ref": "tracking001",
      "status": "success",
      "cost": 1,
      "message_id": "abcd1234-efgh-5678-ijkl-9876543210mn",
      "requested_at": "2024-09-30 14:35:00"
    }
  ]
}
```

**Enhanced Response Methods:** `.delivered?`, `.pending?`, `.failed?`, `.status`, `.requested_at`, `.custom_ref`, `.cost`

---

#### track_delivery(message_id:, timeout:, check_interval:)

Poll message status until it reaches a final state (delivered/failed). **Note:** This blocks the thread. For production, use webhooks instead.

```ruby
response = client.track_delivery(
  message_id: 'msg_12345',
  timeout: 300,           # Maximum wait time (seconds)
  check_interval: 30      # Seconds between status checks
)
```

**Maps to:** Repeated `GET /v1/messages?message_id=...` calls  
**Best Practice:** Use webhooks for production - this method is only suitable for single message tracking

---

#### get_balance()

Get current account credit balance.

```ruby
response = client.get_balance
# Or use alias: client.balance
```

**Maps to:** `GET /v1/account`  
**API Response Example:**
```json
{
  "status": "complete",
  "credit_balance": 1000
}
```

**Enhanced Response Methods:** `.balance`, `.credit_balance`, `.formatted_balance`, `.low_balance?(threshold)`

---

#### parse_webhook(payload)

Parse webhook payload received from Mobile Message. Automatically detects inbound messages vs status updates.

```ruby
# In your webhook endpoint (Rails, Sinatra, etc.)
webhook_data = client.parse_webhook(request.body.read)

case webhook_data
when MobileMessage::SMS::InboundMessage
  # Handle inbound SMS or unsubscribe
  puts webhook_data.from
  puts webhook_data.body
  puts webhook_data.type  # "inbound" or "unsubscribe"
when MobileMessage::SMS::StatusUpdate
  # Handle delivery status update
  puts webhook_data.message_id
  puts webhook_data.status  # "delivered" or "failed"
end
```

**Maps to:** N/A (parses webhook POST data)

**Inbound Webhook Payload Format:**
```json
{
  "to": "61412345678",
  "message": "Hello, this is message 1",
  "sender": "61412345699",
  "received_at": "2024-09-30 14:35:00",
  "type": "inbound",
  "original_message_id": "db6190e1-1ce8-4cdd-b871-244257d57abc",
  "original_custom_ref": "tracking001"
}
```

**Status Webhook Payload Format:**
```json
{
  "to": "61412345678",
  "message": "Hello, this is message 1",
  "sender": "Mobile MSG",
  "custom_ref": "tracking001",
  "status": "delivered",
  "message_id": "044b035f-0396-4a47-8428-12d5273ab04a",
  "received_at": "2024-09-30 14:35:00"
}
```

**Returns:** `InboundMessage` or `StatusUpdate` object

---

#### verify_webhook_signature(payload:, signature:, secret:)

Verify webhook signature to ensure request is from Mobile Message (if signatures are enabled).

```ruby
is_valid = client.verify_webhook_signature(
  payload: request.body.read,
  signature: request.headers['X-Signature'],
  secret: ENV['WEBHOOK_SECRET']
)
```

**Maps to:** N/A (local HMAC-SHA256 verification)  
**Security:** Uses constant-time comparison to prevent timing attacks

---

### Supported Endpoints

The gem supports all core Mobile Message API endpoints:

- `POST /v1/messages` - Send SMS messages (single or bulk up to 100)
- `GET /v1/messages?message_id=...` - Get message delivery status by message ID
- `GET /v1/messages?custom_ref=...` - Get message delivery status by custom reference (supports wildcards)
- `GET /v1/messages?type=inbound` - Poll for inbound SMS messages (webhooks recommended)
- `GET /v1/account` - Get account credit balance
- Webhooks (configured in account settings):
  - Inbound URL - Receive SMS replies and unsubscribe requests in real-time
  - Status URL - Receive delivery receipt notifications in real-time

### Authentication

The Mobile Message API uses HTTP Basic Authentication. Your username and password are encoded and sent with each request:

```ruby
# Authentication is handled automatically by the client
client = MobileMessage.enhanced_sms(
  username: 'your-api-username',  # Your Mobile Message API username
  password: 'your-api-password'   # Your Mobile Message API password
)
```

All requests include:
- `Authorization: Basic <base64_encoded_credentials>` header
- `Content-Type: application/json` header (for POST/PUT)
- `Accept: application/json` header
- `User-Agent: mobilemessage-sms-ruby/{version}` header

## Performance Considerations

### Connection Management

The gem creates a new HTTP connection for each API request. For high-throughput applications (hundreds of requests per second), consider:

1. **Connection Pooling**: Use a connection pool library like `connection_pool` gem
2. **Caching**: Cache message status responses when appropriate
3. **Batch Operations**: Use `broadcast` or `send_bulk` instead of individual `send_sms` calls

### Message Tracking

The `track_delivery` method blocks the thread while polling. For production systems:

- **Use Webhooks**: Configure webhooks for real-time delivery notifications instead of polling
- **Background Jobs**: If polling is necessary, use a background job processor
- **Don't Track Multiple Messages**: This method is only suitable for single message tracking

### Response Caching

Response wrappers automatically memoize expensive operations like message list parsing. Reusing response objects is more efficient than making repeated API calls.

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
