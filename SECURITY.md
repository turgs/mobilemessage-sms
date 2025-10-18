# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |

## Security Features

### Credential Protection
- Credentials are never exposed in logs or error messages
- The `HttpClient#inspect` method masks username and password
- No `attr_reader` for sensitive credential fields

### HTTPS and SSL/TLS
- All API communication uses HTTPS
- SSL certificate verification is enforced (`VERIFY_PEER`)
- TLS version negotiation handled by Ruby's Net::HTTP

### Webhook Security
- HMAC-SHA256 signature verification for webhooks
- Constant-time comparison prevents timing attacks
- Configurable webhook secrets

### Input Validation
- All user inputs are validated before API calls
- Phone numbers, message content, and configuration validated
- Proper error handling for malformed inputs

## Best Practices for Users

### Credential Management
1. **Never hardcode credentials** - Use environment variables or secure credential stores
2. **Rotate credentials regularly** - Change API credentials periodically
3. **Use different credentials** for development, staging, and production

```ruby
# Good - Use environment variables
client = MobileMessage.enhanced_sms(
  username: ENV['MOBILE_MESSAGE_USERNAME'],
  password: ENV['MOBILE_MESSAGE_PASSWORD']
)

# Bad - Hardcoded credentials
client = MobileMessage.enhanced_sms(
  username: 'my-username',
  password: 'my-password'
)
```

### Webhook Security
1. **Always verify signatures** when processing webhooks
2. **Use strong, random secrets** for webhook signature verification
3. **Rotate webhook secrets** regularly

```ruby
def process_webhook(request)
  payload = request.body.read
  signature = request.headers['X-Signature']
  
  unless client.verify_webhook_signature(
    payload: payload,
    signature: signature,
    secret: ENV['WEBHOOK_SECRET']
  )
    return [401, {}, ['Unauthorized']]
  end
  
  # Process webhook...
end
```

### Error Handling
1. **Don't log sensitive data** - Be careful what you log in error handlers
2. **Sanitize error messages** before displaying to end users
3. **Use structured logging** to avoid accidentally logging credentials

### Production Configuration
1. **Set appropriate timeouts** to prevent hanging requests
2. **Enable SSL verification** (enabled by default)
3. **Use sandbox mode only in development**

## Reporting a Vulnerability

If you discover a security vulnerability in this gem, please report it by:

1. **Do NOT open a public issue** - This could put users at risk
2. **Email the maintainers** with details of the vulnerability
3. **Provide steps to reproduce** if possible
4. **Allow time for a fix** before public disclosure

We will acknowledge receipt of your vulnerability report and work with you to understand and resolve the issue promptly.

## Security Updates

Security updates will be released as patch versions and announced in:
- The CHANGELOG.md file
- GitHub Security Advisories
- RubyGems security notifications

## Acknowledgments

We appreciate the security research community's efforts in keeping this gem secure. Contributors who responsibly disclose security issues will be acknowledged (with permission) in the CHANGELOG.
