# Infexor Chat - Implementation Phases

## Overview
WhatsApp-like messaging app with Flutter mobile, Node.js backend, and vanilla JS admin panel.

---

## PHASE 1: Foundation & Project Setup
**Goal**: Set up all three projects with clean architecture, tooling, and base configurations.

### 1.1 Backend Setup
- [ ] Initialize Node.js project with Express 5
- [ ] Set up project structure (routes, controllers, models, middleware, services, utils)
- [ ] Configure MongoDB + Mongoose connection
- [ ] Configure Redis connection
- [ ] Set up environment config (.env management)
- [ ] Add Helmet, CORS, compression, rate limiting middleware
- [ ] Set up error handling middleware
- [ ] Add request validation (Joi or express-validator)
- [ ] Set up logging (Winston or Pino)

### 1.2 Flutter App Setup
- [ ] Create Flutter project with clean architecture structure
- [ ] Set up folder structure (features/, core/, shared/, config/)
- [ ] Configure state management (Riverpod or Bloc)
- [ ] Set up dependency injection
- [ ] Configure app theming (dark modern premium with blue/purple gradient)
- [ ] Add base navigation/routing (GoRouter)
- [ ] Set up HTTP client (Dio) with interceptors
- [ ] Set up local storage (Hive or SharedPreferences)

### 1.3 Admin Panel Setup
- [ ] Create vanilla HTML/CSS/JS project structure
- [ ] Set up base layout (sidebar, header, content area)
- [ ] Configure dark modern theme matching branding
- [ ] Add API utility functions (fetch wrapper with JWT)
- [ ] Set up routing (hash-based SPA routing)

### Deliverable
Three bootstrapped projects with clean architecture, ready for feature development.

---

## PHASE 2: Authentication System
**Goal**: Complete phone-based authentication flow for mobile + admin login.

### 2.1 Backend - Auth APIs
- [ ] User model (phone, name, about, avatar, status, devices, createdAt)
- [ ] Device model (userId, deviceId, fcmToken, platform, lastActive)
- [ ] OTP generation & storage (Redis with TTL)
- [ ] SMS provider integration (Twilio / MSG91 / custom)
- [ ] POST `/auth/send-otp` - Send OTP to phone
- [ ] POST `/auth/verify-otp` - Verify OTP & issue JWT
- [ ] POST `/auth/refresh-token` - Refresh JWT
- [ ] POST `/auth/logout` - Logout current device
- [ ] POST `/auth/logout-all` - Logout from all devices
- [ ] JWT middleware (access + refresh tokens)
- [ ] Rate limiting on OTP endpoints
- [ ] Blocked user check middleware
- [ ] Admin model & separate admin JWT auth
- [ ] POST `/admin/auth/login` - Admin login
- [ ] Admin role-based access middleware

### 2.2 Flutter - Auth Screens
- [ ] Splash screen (dark gradient, logo, glow animation, fade-in)
- [ ] Phone input screen (country picker, phone validation)
- [ ] OTP verification screen (auto-read on Android, resend timer)
- [ ] Profile setup screen (name, about, avatar upload)
- [ ] Auth state management & token storage
- [ ] Auto-login on app restart (token check)
- [ ] Auth flow: Splash → Phone → OTP → Profile Setup → Home

### 2.3 Admin Panel - Login
- [ ] Admin login page
- [ ] JWT token management
- [ ] Session persistence
- [ ] Logout functionality

### Deliverable
Working auth flow end-to-end: phone login, OTP, profile setup, JWT sessions.

---

## PHASE 3: Database Schemas & Core Models
**Goal**: Design and implement all MongoDB schemas with proper indexing.

### 3.1 MongoDB Schemas
- [ ] Users schema (phone, name, about, avatar, privacySettings, blocked[])
- [ ] Devices schema (userId, deviceId, fcmToken, platform)
- [ ] Contacts schema (userId, contactUserId, name, isRegistered)
- [ ] Chats schema (type, participants[], lastMessage, updatedAt)
- [ ] Messages schema (chatId, senderId, type, content, status, replyTo, reactions, starred, deletedFor, createdAt)
- [ ] Groups schema (name, description, avatar, createdBy, inviteLink, settings)
- [ ] GroupMembers schema (groupId, userId, role, joinedAt, mutedUntil)
- [ ] Reports schema (reporterId, targetType, targetId, reason, status)
- [ ] Admins schema (username, password, role, permissions)
- [ ] Broadcasts schema (title, content, segment, scheduledAt, sentAt, status)

### 3.2 Indexing Strategy
- [ ] Users: phone (unique), status
- [ ] Messages: chatId + createdAt (compound), senderId
- [ ] Chats: participants, updatedAt
- [ ] Groups: inviteLink
- [ ] Contacts: userId + contactUserId (compound)
- [ ] Devices: userId, fcmToken

### Deliverable
Complete database layer with optimized schemas and indexes.

---

## PHASE 4: Contact Sync System
**Goal**: Sync device contacts, match registered users, enable invites.

### 4.1 Backend - Contact APIs
- [ ] POST `/contacts/sync` - Accept hashed phone numbers, return matches
- [ ] GET `/contacts` - Get user's synced contacts
- [ ] Fast phone hash index lookup
- [ ] Privacy filtering (respect user settings)
- [ ] Rate limiting on sync endpoint

### 4.2 Flutter - Contact Sync
- [ ] Permission request flow (contacts permission, proper UX)
- [ ] Read device contacts (flutter_contacts)
- [ ] Hash phone numbers (SHA-256) before sending
- [ ] Display matched users with "On Infexor Chat" badge
- [ ] Invite button for non-registered contacts (share link via SMS/other)
- [ ] Background periodic sync (WorkManager)
- [ ] Contact list UI (search, alphabetical scroll)

### Deliverable
Working contact sync with privacy-respecting server matching.

---

## PHASE 5: Real-Time Chat (1-on-1)
**Goal**: Core messaging between two users with real-time delivery.

### 5.1 Backend - Socket.io & Chat APIs
- [ ] Socket.io server setup with JWT auth middleware
- [ ] Connection management (connect, disconnect, reconnect)
- [ ] Redis adapter for Socket.io (scalability)
- [ ] POST `/chats/create` - Create or get existing 1:1 chat
- [ ] GET `/chats` - List user's chats (paginated, sorted by lastMessage)
- [ ] GET `/chats/:id/messages` - Get messages (paginated, cursor-based)
- [ ] Socket events: `message:send`, `message:delivered`, `message:read`
- [ ] Message status tracking (sent → delivered → read)
- [ ] Offline message queuing (deliver when user reconnects)
- [ ] Message persistence in MongoDB

### 5.2 Flutter - Chat UI
- [ ] Chat list screen (conversations, last message, unread count, timestamps)
- [ ] Chat screen (message bubbles, input bar, send button)
- [ ] Text message sending & receiving
- [ ] Emoji keyboard integration
- [ ] Message status indicators (clock, single tick, double tick, blue tick)
- [ ] Socket.io client setup & connection management
- [ ] Local message caching (Hive/SQLite)
- [ ] Pull-to-load older messages
- [ ] Scroll to bottom on new message

### Deliverable
Working 1-on-1 text messaging with real-time delivery and read receipts.

---

## PHASE 6: Presence System & Chat Enhancements
**Goal**: Online status, typing indicators, and advanced message features.

### 6.1 Backend - Presence
- [ ] Redis-based presence tracking
- [ ] Socket heartbeat mechanism
- [ ] Online/offline status broadcasting
- [ ] Last seen timestamp updates
- [ ] Typing indicator events (`typing:start`, `typing:stop`)
- [ ] Recording indicator events
- [ ] Privacy-aware presence (respect user settings)

### 6.2 Flutter - Presence UI & Chat Features
- [ ] Online/offline indicator (green dot)
- [ ] Last seen display ("last seen today at 2:30 PM")
- [ ] Typing indicator ("typing...")
- [ ] Recording indicator ("recording...")
- [ ] Reply to message (swipe gesture + reply preview)
- [ ] Forward message
- [ ] Delete message (for me / for everyone)
- [ ] Message reactions (emoji picker on long press)
- [ ] Starred messages (star/unstar + starred messages screen)
- [ ] Message search within chat
- [ ] Global message search

### Deliverable
Full presence system + WhatsApp-level chat interaction features.

---

## PHASE 7: Media System
**Goal**: Send/receive images, videos, voice notes, documents, location, contacts, GIFs.

### 7.1 Backend - Media APIs
- [ ] Media upload endpoint with file type validation
- [ ] Image compression (Sharp)
- [ ] Video compression (FFmpeg)
- [ ] Cloud storage integration (S3-compatible or local with CDN)
- [ ] Signed URL generation for secure media access
- [ ] Thumbnail generation for images/videos
- [ ] File size limits & validation
- [ ] Media cleanup job (delete orphaned files)

### 7.2 Flutter - Media Features
- [ ] Image picker + camera capture
- [ ] Image compression before upload
- [ ] Image viewer (pinch-to-zoom, save)
- [ ] Video recording + picker
- [ ] Video player (inline + fullscreen)
- [ ] Voice note recording (audio_waveforms or record package)
- [ ] Voice note player with waveform UI
- [ ] Document picker & sharing
- [ ] Location sharing (Google Maps / OpenStreetMap)
- [ ] Contact sharing
- [ ] GIF picker (Giphy/Tenor integration)
- [ ] Media upload progress indicator
- [ ] Auto-download settings (WiFi only, always, never)
- [ ] Chat media gallery (media, docs, links tabs)
- [ ] Media preview in chat bubbles (thumbnails)

### Deliverable
Full media messaging system matching WhatsApp capabilities.

---

## PHASE 8: Group Chat
**Goal**: Complete group messaging with admin controls.

### 8.1 Backend - Group APIs
- [ ] POST `/groups/create` - Create group
- [ ] PUT `/groups/:id` - Update group info (name, description, avatar)
- [ ] POST `/groups/:id/members` - Add members
- [ ] DELETE `/groups/:id/members/:userId` - Remove member
- [ ] PUT `/groups/:id/members/:userId/role` - Change role (admin/member)
- [ ] POST `/groups/:id/invite-link` - Generate invite link
- [ ] POST `/groups/:id/join` - Join via invite link
- [ ] POST `/groups/:id/leave` - Leave group
- [ ] GET `/groups/:id` - Get group info
- [ ] Socket.io group message broadcasting
- [ ] Group message delivery & read tracking

### 8.2 Flutter - Group UI
- [ ] Create group screen (select members, set name/avatar)
- [ ] Group chat screen (reuse chat UI with group features)
- [ ] Group info screen (members list, shared media, settings)
- [ ] Admin controls (add/remove members, change roles)
- [ ] Group invite link sharing
- [ ] Mute group notifications
- [ ] Exit group + confirmation
- [ ] Group system messages ("X added Y", "Z left")

### Deliverable
Complete group chat with admin management.

---

## PHASE 9: Push Notifications
**Goal**: via admin panel on vps server.

### 9.1 Backend - FCM Integration
- [ ] Firebase Admin SDK setup
- [ ] FCM token management (store per device)
- [ ] Send notification on new message (when user offline)
- [ ] Send notification on group events
- [ ] Silent push for background data sync
- [ ] Notification payload formatting (title, body, data)
- [ ] Batch notification sending
- [ ] Custom notification sounds

### 9.2 Flutter - Notification Handling
- [ ] Firebase Messaging setup (firebase_messaging)
- [ ] FCM token registration & refresh
- [ ] Foreground notification handling
- [ ] Background notification handling
- [ ] Notification click routing (navigate to correct chat)
- [ ] Notification channels (Android) with custom sounds
- [ ] Badge count management
- [ ] Local notifications (flutter_local_notifications)

### Deliverable
Reliable push notifications for messages, groups, and system events.

---

## PHASE 10: Privacy & Settings
**Goal**: User privacy controls and app settings.

### 10.1 Backend - Privacy APIs
- [ ] PUT `/users/privacy` - Update privacy settings
- [ ] POST `/users/block/:userId` - Block user
- [ ] DELETE `/users/block/:userId` - Unblock user
- [ ] GET `/users/blocked` - Get blocked users list
- [ ] Privacy enforcement across all APIs (last seen, profile photo, about, read receipts)

### 10.2 Flutter - Settings Screens
- [ ] Settings main screen
- [ ] Account settings (privacy, security, change number)
- [ ] Last seen privacy (Everyone / My Contacts / Nobody)
- [ ] Profile photo privacy
- [ ] About privacy
- [ ] Read receipts toggle
- [ ] Blocked contacts screen
- [ ] Chat settings (wallpaper, font size, media auto-download)
- [ ] Notification settings (tones, vibration, popup)
- [ ] Storage & data usage
- [ ] Help/About screen
- [ ] Profile edit screen (name, about, avatar)

### Deliverable
Complete privacy controls and settings matching WhatsApp.

---

## PHASE 11: Admin Panel (Full)
**Goal**: Complete web admin panel with all management features.

### 11.1 Dashboard
- [x] Total users counter (with growth chart)
- [x] Active users (daily/weekly/monthly)
- [x] Messages per day chart
- [x] Media storage usage
- [x] Server health indicators (CPU, RAM, disk)
- [x] Real-time active sockets count

### 11.2 User Management
- [x] User list with search & filters
- [x] User detail view (profile, activity, devices)
- [x] Ban/suspend user actions
- [x] Force logout user
- [x] View user's devices
- [x] User activity log

### 11.3 Reports System
- [x] User reports list with filters
- [x] Message reports with content preview
- [x] Group reports
- [x] Action tools (warn, ban, delete content, dismiss)
- [x] Report status tracking (pending, reviewed, resolved)

### 11.4 Broadcast System
- [x] Send push notification to all users
- [x] User segmentation (by activity, platform, registration date)
- [x] Schedule broadcasts for later
- [x] Broadcast history & delivery stats

### 11.5 System Monitoring
- [x] Active socket connections
- [x] Server CPU/RAM monitoring
- [x] Error log viewer
- [x] Notification delivery status
- [x] API response time monitoring

### Deliverable
Full admin panel with dashboard, user management, reports, broadcasts, and monitoring.

---

## PHASE 12: Security Hardening & Optimization
**Goal**: Production-grade security and performance.

### 12.1 Security
- [ ] Input validation on all endpoints (sanitize everything)
- [ ] Rate limiting fine-tuning (per-endpoint limits)
- [ ] JWT expiry & refresh token rotation
- [ ] Secure media URLs (signed, time-limited)
- [ ] OTP brute-force protection
- [ ] Spam detection hooks
- [ ] Abuse detection (message flooding, mass group creation)
- [ ] HTTPS enforcement
- [ ] Security headers (Helmet configuration)
- [ ] MongoDB injection prevention
- [ ] XSS prevention

### 12.2 Performance
- [ ] Database query optimization (explain & index tuning)
- [ ] Message pagination optimization
- [ ] Image/media lazy loading
- [ ] Socket.io connection pooling
- [ ] Redis caching strategy (frequently accessed data)
- [ ] Flutter app performance profiling
- [ ] Reduce app bundle size
- [ ] API response compression

### Deliverable
Hardened, optimized application ready for production traffic.

---

## PHASE 13: VPS Deployment
**Goal**: Deploy everything to production VPS.

### 13.1 Server Setup
- [ ] Nginx reverse proxy configuration (API + Socket.io + Admin)
- [ ] SSL/TLS certificate (Let's Encrypt)
- [ ] PM2 process manager setup (cluster mode)
- [ ] MongoDB production configuration (replica set, auth)
- [ ] Redis production configuration
- [ ] Environment variable management
- [ ] Firewall rules (UFW)
- [ ] Log rotation setup

### 13.2 CI/CD & Monitoring
- [ ] Deployment scripts
- [ ] Health check endpoints
- [ ] PM2 monitoring
- [ ] MongoDB backup strategy (automated)
- [ ] Error alerting (email/webhook)
- [ ] Uptime monitoring

### 13.3 Mobile App Release
- [ ] Android release build & signing
- [ ] iOS release build & signing
- [ ] App store assets (screenshots, descriptions)
- [ ] Play Store / App Store submission prep
acces my vps using key D:\DEVELOPMENTS\Portfolio\vps_access  and ip 72.61.171.190
### Deliverable
Fully deployed, monitored production system.

---

## Phase Timeline Summary

| Phase | Name | Dependencies |
|-------|------|-------------|
| 1 | Foundation & Project Setup | None |
| 2 | Authentication System | Phase 1 |
| 3 | Database Schemas & Core Models | Phase 1 |
| 4 | Contact Sync | Phase 2, 3 |
| 5 | Real-Time Chat (1-on-1) | Phase 2, 3 |
| 6 | Presence & Chat Enhancements | Phase 5 |
| 7 | Media System | Phase 5 |
| 8 | Group Chat | Phase 5 |
| 9 | Push Notifications | Phase 5 |
| 10 | Privacy & Settings | Phase 6 |
| 11 | Admin Panel (Full) | Phase 2, 3 |
| 12 | Security & Optimization | Phase 1-11 |
| 13 | VPS Deployment | Phase 12 |

> **Note**: Phases 4-9 and 11 can partially overlap. Phase 3 can be done alongside Phase 2.
> Phase 11 (Admin Panel) can be developed in parallel with mobile features.
