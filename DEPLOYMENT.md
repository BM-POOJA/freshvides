# Deployment Guide

## Environment Variables Required

Configure these environment variables in your Render.com dashboard:

### 1. Database Configuration

- `DATABASE_HOST` - Your PostgreSQL host
- `DATABASE_PORT` - PostgreSQL port (default: 5432)
- `DATABASE_NAME` - Database name
- `DATABASE_USERNAME` - Database username
- `DATABASE_PASSWORD` - Database password

### 2. Cloudinary Configuration (REQUIRED)

- `CLOUDINARY_CLOUD_NAME` - Your Cloudinary cloud name
- `CLOUDINARY_API_KEY` - Your Cloudinary API key
- `CLOUDINARY_API_SECRET` - Your Cloudinary API secret

**To get your Cloudinary credentials:**

1. Sign up at https://cloudinary.com
2. Go to Dashboard
3. Copy the following from your dashboard:
   - **Cloud name** → Set as `CLOUDINARY_CLOUD_NAME`
   - **API Key** → Set as `CLOUDINARY_API_KEY`
   - **API Secret** → Set as `CLOUDINARY_API_SECRET`
4. Add all three as environment variables in Render

**Note:** The API now uses **signed uploads** for enhanced security. No upload preset configuration is required.

### 3. Render Configuration

**Web Service Settings:**

- **Build Command**: `dart pub global activate dart_frog_cli && dart_frog build`
- **Start Command**: `cd build && dart pub get && dart bin/server.dart`
- **Environment**: Docker (or Native if preferred)
- **Instance Type**: At least 512MB RAM recommended for video uploads

**Auto-Deploy**: Enable from your Git repository

## Testing Locally

1. Create a `.env` file in the project root:

```env
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_NAME=freshvibes
DATABASE_USERNAME=postgres
DATABASE_PASSWORD=yourpassword
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_API_KEY=your_api_key
CLOUDINARY_API_SECRET=your_api_secret
```

2. Run the server:

```bash
dart_frog dev
```

3. Test with curl:

```bash
# Test photo upload
curl -X POST http://localhost:8080/postphotos \
  -F "user_id=1" \
  -F "description=Test photo" \
  -F "photo=@test_image.jpg"

# Test video upload
curl -X POST http://localhost:8080/postvideos \
  -F "user_id=1" \
  -F "title=Test video" \
  -F "description=Test description" \
  -F "duration=15" \
  -F "video=@test_video.mp4"
```

## Common Issues

### 1. "Failed to upload to Cloudinary" Error

- **Cause**: Missing Cloudinary credentials or authentication failure
- **Solution**:
  - Verify all three environment variables are set in Render:
    - `CLOUDINARY_CLOUD_NAME`
    - `CLOUDINARY_API_KEY`
    - `CLOUDINARY_API_SECRET`
  - Check Cloudinary dashboard logs
  - Ensure API credentials are correct (no extra spaces)

### 2. 502 Bad Gateway / ECONNRESET

- **Cause**: Server timeout or crash during video upload
- **Solution**:
  - Video uploads now have 120-second timeout
  - Ensure Render instance has enough RAM (512MB+)
  - Check Render logs for memory issues
  - Consider upgrading Render plan for larger files

### 3. Server Configuration Error

- **Cause**: Cloudinary environment variables not configured
- **Solution**: Add all three Cloudinary variables in Render dashboard → Environment

## Monitoring

Check Render logs for detailed error messages:

- ❌ Icons indicate errors
- ✅ Icons indicate successful uploads
- Look for "CLOUDINARY_CLOUD_NAME environment variable not set"

## Video Upload Limits

- Maximum duration: 30 seconds
- One upload at a time per user
- 120-second timeout for upload completion
