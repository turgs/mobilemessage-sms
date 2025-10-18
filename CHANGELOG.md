# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Security
- Removed `attr_reader` for username and password to prevent credential exposure in logs
- Added `#inspect` method to HttpClient that masks credentials
- Fixed timing attack vulnerability in webhook signature verification by using constant-time comparison
- Added explicit SSL certificate verification (VERIFY_PEER) for all HTTPS connections

### Changed
- Replaced bare `rescue` with specific exception handling in time parsing methods
- Added memoization to MessagesListResponse#messages for improved performance
- Extracted magic numbers to constants in Configuration class for better maintainability
- Updated retry delay calculation to use Configuration constants

### Added
- Performance considerations section in README
- Documentation about connection management and high-throughput scenarios
- Warning about track_delivery blocking behavior in README
- Test for webhook signature verification with constant-time comparison

## [0.1.0] - 2025-10-18

### Added
- Initial release of mobilemessage-sms gem
- Send SMS functionality (single and bulk messages)
- Receive SMS via webhooks
- Message status checking and delivery tracking
- Account balance checking
- Enhanced response objects with convenience methods
- Comprehensive error handling with specific error types
- Raw and enhanced response format options
- Sandbox mode for testing
- Full API documentation in README
- Test infrastructure with minitest
- Examples directory with sample usage
