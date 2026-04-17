# JWT Authentication Flow

How authentication works in the RAG Assistant — from registration to token refresh.

## Overview

```
+----------+         +----------+         +----------+
|  Flutter |  <--->  |  FastAPI |  <--->  | Database |
|   App    |  JWT    |  Backend |  SQL    | (SQLite) |
+----------+         +----------+         +----------+
```

JWT (JSON Web Token) is a stateless authentication system. The server never stores sessions — instead, it issues signed tokens that the client sends with every request.

---

## Flow 1: Registration

```
Flutter                          Backend                         Database
  |                                |                                |
  |  POST /auth/register           |                                |
  |  {email, password, name}       |                                |
  |------------------------------->|                                |
  |                                |  Check: email already exists?  |
  |                                |------------------------------->|
  |                                |  No duplicate found            |
  |                                |<-------------------------------|
  |                                |                                |
  |                                |  Hash password (bcrypt)        |
  |                                |  "test123" --> "$2b$12$..."    |
  |                                |                                |
  |                                |  INSERT user                   |
  |                                |------------------------------->|
  |                                |  User created (id: abc-123)    |
  |                                |<-------------------------------|
  |                                |                                |
  |                                |  Generate tokens:              |
  |                                |  Access:  sign({              |
  |                                |    sub: "abc-123",            |
  |                                |    email: "test@test.com",    |
  |                                |    exp: now + 15min,          |
  |                                |    type: "access"             |
  |                                |  }, JWT_SECRET)               |
  |                                |                                |
  |                                |  Refresh: sign({              |
  |                                |    sub: "abc-123",            |
  |                                |    email: "test@test.com",    |
  |                                |    exp: now + 7days,          |
  |                                |    type: "refresh"            |
  |                                |  }, JWT_SECRET)               |
  |                                |                                |
  |  {access_token, refresh_token} |                                |
  |<-------------------------------|                                |
  |                                |                                |
  |  Store tokens in               |                                |
  |  FlutterSecureStorage          |                                |
  |  Navigate to Chat screen       |                                |
```

---

## Flow 2: Login

```
Flutter                          Backend                         Database
  |                                |                                |
  |  POST /auth/login              |                                |
  |  {email, password}             |                                |
  |------------------------------->|                                |
  |                                |  Find user by email            |
  |                                |------------------------------->|
  |                                |  User found                    |
  |                                |<-------------------------------|
  |                                |                                |
  |                                |  Verify password:              |
  |                                |  bcrypt.verify(                |
  |                                |    "test123",                  |
  |                                |    "$2b$12$..."                |
  |                                |  ) --> true                    |
  |                                |                                |
  |                                |  Generate new token pair       |
  |                                |  (same as registration)        |
  |                                |                                |
  |  {access_token, refresh_token} |                                |
  |<-------------------------------|                                |
  |                                |                                |
  |  Store tokens, set on ApiClient|                                |
  |  Navigate to Chat screen       |                                |


  LOGIN FAILURE:

  |  POST /auth/login              |                                |
  |  {email, wrong_password}       |                                |
  |------------------------------->|                                |
  |                                |  bcrypt.verify() --> false     |
  |  401 "Invalid email or password"|                               |
  |<-------------------------------|                                |
```

---

## Flow 3: Authenticated API Request

```
Flutter                          Backend
  |                                |
  |  POST /chat/query              |
  |  Headers:                      |
  |    Authorization: Bearer eyJ... |
  |  Body: {question: "hi"}       |
  |------------------------------->|
  |                                |
  |                   +---------------------+
  |                   | get_current_user()   |
  |                   |                     |
  |                   | 1. Extract token    |
  |                   |    from "Bearer ..." |
  |                   |                     |
  |                   | 2. Decode JWT:      |
  |                   |    jwt.decode(      |
  |                   |      token,         |
  |                   |      JWT_SECRET     |
  |                   |    )                |
  |                   |                     |
  |                   | 3. Check expiry:    |
  |                   |    exp > now?       |
  |                   |    Yes --> continue |
  |                   |    No  --> 401      |
  |                   |                     |
  |                   | 4. Check type:      |
  |                   |    type == "access"?|
  |                   |    Yes --> continue |
  |                   |                     |
  |                   | 5. Load user from DB|
  |                   |    WHERE id = sub   |
  |                   |                     |
  |                   | Return User object  |
  |                   +---------------------+
  |                                |
  |                                |  Process chat query
  |                                |  (with user.id for RAG)
  |                                |
  |  {answer, sources}             |
  |<-------------------------------|


  EXPIRED TOKEN:

  |  POST /chat/query              |
  |  Authorization: Bearer eyJ...  |
  |------------------------------->|
  |                                |
  |                   jwt.decode() --> ExpiredSignatureError
  |                                |
  |  401 "Invalid or expired token"|
  |<-------------------------------|
```

---

## Flow 4: Automatic Token Refresh

```
Flutter                          Backend
  |                                |
  |  POST /chat/query              |
  |  Authorization: Bearer [expired]|
  |------------------------------->|
  |  401 Unauthorized              |
  |<-------------------------------|
  |                                |
  |  [AuthInterceptor catches 401] |
  |                                |
  |  POST /auth/refresh            |
  |  {refresh_token: "eyJ..."}     |
  |------------------------------->|
  |                                |
  |                   Decode refresh token
  |                   Check type == "refresh"
  |                   Check not expired (7 days)
  |                   Generate new token pair
  |                                |
  |  {new_access, new_refresh}     |
  |<-------------------------------|
  |                                |
  |  Update stored tokens          |
  |  Retry original request        |
  |                                |
  |  POST /chat/query              |
  |  Authorization: Bearer [new]   |
  |------------------------------->|
  |  {answer, sources}             |
  |<-------------------------------|
  |                                |
  |  User never sees the refresh!  |


  REFRESH TOKEN ALSO EXPIRED (after 7 days):

  |  POST /auth/refresh            |
  |  {refresh_token: [expired]}    |
  |------------------------------->|
  |  401 "Invalid or expired token"|
  |<-------------------------------|
  |                                |
  |  Redirect to Login screen      |
```

---

## What's Inside a JWT Token?

A JWT has 3 parts separated by dots: `header.payload.signature`

```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJhYmMtMTIzIiwiZW1haWwiOiJ0ZXN0QHRlc3QuY29tIiwiZXhwIjoxNzE3NTA4MzEwLCJ0eXBlIjoiYWNjZXNzIn0.iP50RNTcP6JO852UcJeiPVC1fwZ6ZxlQFpc2XKnCcgU
```

### Header (Base64 encoded)
```json
{
  "alg": "HS256",
  "typ": "JWT"
}
```
The signing algorithm — HS256 (HMAC with SHA-256).

### Payload (Base64 encoded)
```json
{
  "sub": "abc-123",          // User ID
  "email": "test@test.com",  // User email
  "exp": 1717508310,         // Expiry timestamp
  "type": "access"           // Token type (access or refresh)
}
```
This data is readable by anyone (just Base64) — but it can't be *modified* without the secret.

### Signature
```
HMAC-SHA256(
  base64(header) + "." + base64(payload),
  JWT_SECRET
)
```
The server signs the token with `JWT_SECRET`. If anyone tampers with the payload, the signature won't match and the token is rejected.

---

## Token Lifecycle

```
        REGISTER / LOGIN
              |
              v
    +-------------------+
    | Access Token      |    +-------------------+
    | Lifespan: 15 min  |    | Refresh Token     |
    | Used for: API calls|   | Lifespan: 7 days  |
    +--------+----------+    | Used for: getting  |
             |               | new access tokens  |
             |               +--------+----------+
             v                        |
      [Every API request]             |
      Authorization: Bearer ...       |
             |                        |
             v                        |
      +------+-------+               |
      | Token valid?  |               |
      +---+------+---+               |
      Yes |      | No (expired)       |
          |      +--------+           |
          v               v           |
    [Process request]  [401 Error]    |
                          |           |
                          v           |
                   [Use refresh token]|
                          +---------->+
                                      |
                                      v
                              [New token pair]
                                      |
                              +-------+--------+
                              |                |
                        New Access       New Refresh
                        (15 min)         (7 days)
```

---

## Security Features

| Feature | Implementation | Why |
|---------|---------------|-----|
| Password hashing | bcrypt via passlib | Passwords never stored in plain text |
| Short-lived access tokens | 15 minutes | Limits damage if token is stolen |
| Long-lived refresh tokens | 7 days | User doesn't need to login constantly |
| Token type checking | `type: "access"` vs `"refresh"` | Prevents using refresh token as access token |
| Secure storage (Flutter) | flutter_secure_storage | Tokens encrypted on device (Keychain/Keystore) |
| Auto-refresh | AuthInterceptor | Seamless token renewal without user action |
| Per-user data isolation | `user_id` from JWT payload | Each user only sees their own data |

---

## Code Map

| File | Role |
|------|------|
| `app/auth/jwt_handler.py` | Token creation, verification, `get_current_user` dependency |
| `app/auth/router.py` | Register, login, refresh endpoints |
| `app/models/user.py` | User database model (id, email, hashed_password) |
| `lib/core/auth_interceptor.dart` | Auto-refresh on 401, injects Bearer header |
| `lib/core/api_client.dart` | Dio HTTP client with auth interceptor |
| `lib/features/auth/providers/auth_provider.dart` | Login/register logic, secure token storage |
| `lib/features/auth/screens/login_screen.dart` | Login/register UI |

---

## Common Scenarios

### First time user
```
Open app --> No stored tokens --> Redirect to /login --> Register --> Get tokens --> Chat
```

### Returning user (within 7 days)
```
Open app --> Load tokens from secure storage --> tryAutoLogin() --> Chat
```

### Returning user (after 7 days)
```
Open app --> Load tokens --> API call fails --> Refresh fails --> Redirect to /login
```

### Token expires mid-session
```
Chatting --> Access token expires --> 401 --> Auto-refresh --> New tokens --> Retry --> Works
```
