# PRD: User Authentication System

## Overview

Implement a secure user authentication system supporting email/password login and OAuth providers.

## Goals

- Enable users to create accounts and log in securely
- Support multiple authentication methods
- Provide password reset functionality
- Maintain secure session management

## Non-Goals

- Two-factor authentication (future phase)
- Admin user management UI
- SAML/enterprise SSO

## Requirements

### Must Have

1. Email/password registration with email verification
2. Login with email/password
3. Password reset via email
4. Session management with JWT
5. Logout functionality

### Should Have

6. Google OAuth login
7. GitHub OAuth login
8. Remember me functionality
9. Rate limiting on login attempts

### Nice to Have

10. Password strength indicator
11. Login history/audit log

## Technical Approach

- Use bcrypt for password hashing (cost factor 12)
- JWT access tokens (15 min expiry) + refresh tokens (7 days)
- Store refresh tokens in HTTP-only secure cookies
- Use existing OAuth library (passport.js or similar)

## Success Metrics

- < 500ms login response time
- Zero password storage in plaintext
- All OAuth flows complete successfully

## Timeline

Not specified - autopilot will work through requirements sequentially.

## Open Questions

Resolved during PRD generation:
- Q: OAuth providers? A: Google and GitHub for initial release
- Q: Email verification required? A: Yes, before first login
- Q: Session duration? A: 15 min access token, 7 day refresh
