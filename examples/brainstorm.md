# Feature Brainstorm: User Authentication

## Initial Ideas

- Users need to log in to access protected features
- Want to support email/password and OAuth (Google, GitHub)
- Need password reset functionality
- Session management with JWT tokens
- Remember me functionality

## Questions to Explore

1. Should we support 2FA?
2. What OAuth providers are essential?
3. How long should sessions last?
4. Do we need email verification?

## Technical Considerations

- Use bcrypt for password hashing
- Store refresh tokens in HTTP-only cookies
- Rate limit login attempts
- Consider using existing auth library vs building custom

## Next Steps

Feed this into `/prd user-auth` to generate a structured PRD.
