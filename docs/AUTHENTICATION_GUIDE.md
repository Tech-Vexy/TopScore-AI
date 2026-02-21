# Authentication Implementation Guide

## Overview
This document describes the authentication implementation for TopScore AI, including Google OAuth and Email/Password authentication with email verification and fraud prevention.

## Authentication Methods

### 1. Google Sign-In
- **Provider**: Google OAuth 2.0
- **Verification**: Google accounts are pre-verified by Google, so no additional email verification is required
- **Implementation**: Uses `google_sign_in` package with Firebase Authentication
- **Flow**:
  1. User clicks "Continue with Google"
  2. Google authentication popup appears
  3. User authenticates with Google
  4. Firebase creates/retrieves user account
  5. User profile is created/loaded from Firestore

### 2. Email/Password Authentication
- **Provider**: Firebase Authentication
- **Verification**: Required for all email/password accounts
- **Fraud Prevention**: Disposable email domains are blocked
- **Flow**:
  1. User enters email and password
  2. System validates email format and domain
  3. If signing up:
     - Check email domain against blocked list
     - Create Firebase account
     - Send verification email
     - Redirect to verification screen
  4. If signing in:
     - Verify email has been confirmed
     - If not verified, send new verification email
     - If verified, complete sign-in

## Email Verification

### Why It's Required
- Prevents spam accounts
- Ensures valid contact information
- Reduces fraudulent sign-ups
- Protects against automated bot registrations

### Verification Flow
1. User signs up with email/password
2. Firebase sends verification email automatically
3. User is redirected to `EmailVerificationScreen`
4. User clicks verification link in email
5. User returns to app and clicks "I've Verified My Email"
6. System reloads Firebase user and checks verification status
7. If verified, user gains full access

### Verification Screen Features
- Clear instructions for the user
- "I've Verified My Email" button to check status
- "Resend verification email" button
- "Back to Sign In" to return to login

## Fraud Prevention

### Blocked Email Domains
The system maintains a list of disposable/temporary email providers that are blocked from registration.

**Location**: `assets/config/blocked_email_domains.json`

**Default blocked domains include**:
- mailinator.com
- 10minutemail.com
- tempmail.com
- guerrillamail.com
- yopmail.com
- And 40+ more disposable email services

### How It Works
1. When user attempts to sign up, system loads blocked domains list
2. Email domain is extracted from the email address
3. Domain is checked against the blocked list
4. If blocked, registration is rejected with error message
5. If allowed, registration proceeds

### Updating Blocked Domains
To add more blocked domains:
1. Edit `assets/config/blocked_email_domains.json`
2. Add domain strings to the JSON array
3. Domains are case-insensitive and automatically trimmed

## Guest Access

**Status**: DISABLED

Guest access has been intentionally disabled to ensure:
- All users have verified accounts
- Better user engagement tracking
- Reduced abuse and spam
- Valid contact information for all users

The `continueAsGuest()` method now throws an exception if called.

## Implementation Details

### AuthProvider Methods

#### Core Authentication
- `signInWithGoogle()` - Google OAuth sign-in
- `signInWithEmail(email, password)` - Email/password sign-in
- `signUpWithEmail(email, password)` - New account registration
- `signOut()` - Sign out current user

#### Verification
- `resendEmailVerification()` - Resend verification email
- `reloadAndCheckEmailVerified()` - Check if email is now verified
- `sendPasswordReset(email)` - Send password reset email

#### State
- `requiresEmailVerification` - Boolean flag indicating verification needed
- `userModel` - Current authenticated user or null
- `isLoading` - Loading state for async operations

### UI Components

#### LoginScreen
- Google sign-in button
- Email/password form with toggle between sign-in/sign-up
- Form validation
- Password visibility toggle
- "Forgot password" functionality
- Error handling and user feedback

#### EmailVerificationScreen
- Verification instructions
- Check verification status
- Resend verification email
- Return to sign-in

### Firebase Rules Integration

Both Firestore and Storage rules require authentication:

```javascript
function isAuthenticated() {
  return request.auth != null;
}
```

Anonymous users are no longer supported in the security rules.

## Password Requirements

- Minimum length: 6 characters
- No special character requirements (Firebase default)
- Passwords are securely hashed by Firebase

## Error Handling

### Common Errors
- **"Disposable or fraudulent email providers are not allowed"**: User tried to register with a blocked email domain
- **"Check your email to verify your account"**: Email verification required before access
- **"Email not verified yet"**: User tried to sign in but hasn't verified email
- **"Password must be at least 6 characters"**: Password too short

### User Feedback
- All errors are displayed via `SnackBar`
- Success messages confirm actions (password reset sent, verification email sent)
- Loading states prevent double-submissions

## Security Considerations

### Current Implementation
✅ Email verification required for email/password auth
✅ Disposable email domains blocked
✅ Google accounts are pre-verified
✅ Guest access disabled
✅ Passwords hashed by Firebase
✅ Firestore rules require authentication

### Best Practices
- Never store passwords in plain text (handled by Firebase)
- Always use HTTPS (handled by Firebase/Flutter)
- Rate limiting on auth attempts (handled by Firebase)
- Email verification prevents fake accounts
- Blocked domains prevent disposable emails

## Testing

### Test Scenarios

#### Google Sign-In
1. Click "Continue with Google"
2. Complete Google authentication
3. Verify redirect to home screen
4. Verify user profile created in Firestore

#### Email Sign-Up
1. Enter valid email (not blocked domain)
2. Enter password (6+ characters)
3. Click "Create Account"
4. Verify redirect to verification screen
5. Check email for verification link
6. Click verification link
7. Return to app and click "I've Verified My Email"
8. Verify redirect to home screen

#### Email Sign-In
1. Enter registered email
2. Enter correct password
3. Click "Sign In"
4. If not verified, see verification screen
5. If verified, see home screen

#### Blocked Domain Test
1. Try to register with mailinator.com email
2. Verify error message appears
3. Confirm registration is rejected

#### Password Reset
1. Enter email in sign-in form
2. Click "Forgot password?"
3. Verify password reset email sent
4. Check email for reset link
5. Complete password reset flow
6. Sign in with new password

## Future Enhancements

### Recommended Additions
- [ ] SMS verification for added security
- [ ] Two-factor authentication (2FA)
- [ ] Social sign-in (Apple, Facebook)
- [ ] Account recovery options
- [ ] Login activity tracking
- [ ] Device management
- [ ] Session timeout
- [ ] Biometric authentication (fingerprint/face)

### Blocked Domains Maintenance
- Regularly update blocked domains list
- Consider using a third-party API for real-time disposable email detection
- Monitor registration patterns for new disposable providers

## Support Resources

### Firebase Documentation
- [Firebase Authentication](https://firebase.google.com/docs/auth)
- [Email Verification](https://firebase.google.com/docs/auth/web/manage-users#send_a_user_a_verification_email)
- [Google Sign-In](https://firebase.google.com/docs/auth/flutter/google-signin)

### Package Documentation
- [google_sign_in](https://pub.dev/packages/google_sign_in)
- [firebase_auth](https://pub.dev/packages/firebase_auth)

## Troubleshooting

### Google Sign-In Not Working
- Verify Google OAuth credentials in Firebase Console
- Check SHA-1 fingerprint for Android
- Verify OAuth consent screen configured
- Ensure google-services.json is up to date

### Email Verification Not Received
- Check spam folder
- Verify Firebase email template is configured
- Ensure sender domain is not blacklisted
- Use "Resend verification email" button

### Blocked Domain False Positives
- Review blocked_email_domains.json
- Remove legitimate domains if accidentally blocked
- Consider whitelist for educational institutions

## Maintenance

### Regular Tasks
- Review and update blocked email domains monthly
- Monitor authentication error logs
- Track verification completion rates
- Update Firebase SDK versions
- Review security rules

### Monitoring Metrics
- Sign-up success rate
- Email verification completion rate
- Google vs Email/Password adoption
- Authentication errors frequency
- Blocked domain rejection rate
