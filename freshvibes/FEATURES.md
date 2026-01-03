# FreshVibes - Photo & Video Sharing App

## Features Implemented

### 1. Authentication

- **Signup Screen**: Create a new account with username, email, and password
- **Login Screen**: Sign in with username and password
- Both screens feature beautiful animated UI with gradient backgrounds

### 2. Home Screen

- **Feed View**: Vertical scrolling feed (like TikTok/Instagram Reels)
- Displays photos and videos one at a time
- Shows user information, descriptions, and interaction buttons
- Like, comment, share, and bookmark functionality (UI ready)

### 3. Profile Screen

- View user profile with stats (Posts, Followers, Following)
- **Upload Photos**: Select from gallery and upload with description
- **Upload Videos**: Select from gallery and upload with description
- Progress indicator during uploads

## API Endpoints Used

- **Signup**: `POST https://freshvides.onrender.com/signup`
- **Login**: `POST https://freshvides.onrender.com/login`
- **Post Photos**: `POST https://freshvides.onrender.com/postphotos`
  - Fields: `user_id`, `description`, `photo` (multipart)
- **Post Videos**: `POST https://freshvides.onrender.com/postvideos`
  - Fields: `user_id`, `description`, `video` (multipart)

## Navigation Flow

1. App starts at **Signup Screen**
2. Click "Sign in" → Navigate to **Login Screen**
3. After successful login → Navigate to **Home Screen**
4. Home Screen has bottom navigation:
   - **Home Tab**: Feed with scrolling content
   - **Profile Tab**: User profile with upload options

## Packages Used

- `http: ^1.2.0` - API calls
- `image_picker: ^1.1.2` - Photo/video selection

## Setup Instructions

1. Install dependencies:

   ```bash
   flutter pub get
   ```

2. Run the app:
   ```bash
   flutter run
   ```

## Notes

- User ID is automatically passed from login response to upload functions
- All uploads require a description entered via dialog
- The feed currently shows sample data (can be replaced with API data)
