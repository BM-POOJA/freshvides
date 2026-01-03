# Debugging Guide - How to Find Errors

## 📋 Step 1: Check Render Logs

The logs will show you exactly what's failing:

1. Go to your Render dashboard: https://dashboard.render.com
2. Click on your **freshvides** service
3. Click **Logs** tab (top navigation)
4. Look for recent log entries when you made the API request

### What to Look For:

#### ✅ Successful Upload Logs:

```
📸 Starting Cloudinary upload process...
🔍 Checking Cloudinary credentials...
  Cloud Name: ✅ Set
  API Key: ✅ Set
  API Secret: ✅ Set
✅ All Cloudinary credentials found
📤 Upload URL: https://api.cloudinary.com/v1_1/dsgi5rvvp/image/upload
🔐 Generating signature...
✅ Signature generated: a1b2c3d4e5...
📦 File size: 12345 bytes
⏳ Sending request to Cloudinary...
📥 Cloudinary Response Status: 200
✅ Photo uploaded to Cloudinary: https://...
```

#### ❌ Error Logs - Missing Credentials:

```
📸 Starting Cloudinary upload process...
🔍 Checking Cloudinary credentials...
  Cloud Name: ✅ Set
  API Key: ❌ Missing
  API Secret: ❌ Missing
❌ Cloudinary environment variables not properly configured
```

**Solution**: Environment variables not set in Render

- Go to Render dashboard → Your service → Environment
- Add missing variables

#### ❌ Error Logs - Cloudinary Upload Failed:

```
⏳ Sending request to Cloudinary...
📥 Cloudinary Response Status: 401
📥 Response Body: {"error":{"message":"Invalid signature"}}
❌ Cloudinary upload failed (401): ...
```

**Solution**: Check signature generation or API credentials

#### ❌ Error Logs - Timeout:

```
⏳ Sending request to Cloudinary (with 120s timeout)...
❌ Post Video Error: TimeoutException: Cloudinary upload timed out after 120 seconds
```

**Solution**: File too large or slow connection. Increase timeout or reduce file size.

## 📋 Step 2: Verify Environment Variables

In Render dashboard, check these are ALL set:

```
CLOUDINARY_CLOUD_NAME=dsgi5rvvp
CLOUDINARY_API_KEY=691711488137652
CLOUDINARY_API_SECRET=1aOIkG5lmJXxa-4O_6NWE0S6skc
DB_HOST=...
DB_NAME=...
DB_PASSWORD=...
DB_PORT=5432
DB_USER=...
```

### How to Check:

1. Render dashboard → Your service → Environment tab
2. Make sure ALL variables are visible
3. **Important**: After adding/editing, you must redeploy!

## 📋 Step 3: Test API Response

Look at the error response from Postman/API client:

### If you get:

```json
{
  "error": "Server configuration error: Cloudinary not configured"
}
```

**Cause**: Environment variables missing or not loaded  
**Fix**: Check Render environment variables and redeploy

### If you get:

```json
{
  "error": "Failed to upload to Cloudinary",
  "details": "Status 401",
  "cloudinary_response": "..."
}
```

**Cause**: Invalid Cloudinary credentials or signature  
**Fix**:

- Verify API key and secret are correct
- Check for extra spaces in environment variables
- Regenerate API secret in Cloudinary if needed

### If you get:

```json
{
  "error": "User not found"
}
```

**Cause**: The user_id doesn't exist in database  
**Fix**: Create user first via `/signup` endpoint or use valid user_id

### If you get 502 Bad Gateway:

**Cause**: Server crashed or timed out  
**Fix**:

- Check Render logs for crash details
- Increase instance size (more RAM)
- For videos: ensure duration < 30 seconds

## 📋 Step 4: Common Issues Checklist

- [ ] Environment variables set in Render (not just local .env)
- [ ] Redeployed after adding environment variables
- [ ] Cloudinary credentials copied exactly (no spaces)
- [ ] Using correct user_id (user exists in database)
- [ ] File is valid image/video format
- [ ] For videos: duration parameter provided
- [ ] For videos: duration <= 30 seconds

## 📋 Step 5: Test Cloudinary Credentials Manually

Test if your Cloudinary account works:

### Using curl (from terminal):

```bash
# Test with timestamp
TIMESTAMP=$(date +%s)
SIGNATURE=$(echo -n "timestamp=${TIMESTAMP}YOUR_API_SECRET" | openssl dgst -sha256 | awk '{print $2}')

curl -X POST "https://api.cloudinary.com/v1_1/dsgi5rvvp/image/upload" \
  -F "file=@test.jpg" \
  -F "api_key=691711488137652" \
  -F "timestamp=${TIMESTAMP}" \
  -F "signature=${SIGNATURE}"
```

**Expected**: Should return JSON with `secure_url`  
**If fails**: Problem with Cloudinary credentials

## 📋 Step 6: Database Connection Issues

If you see database errors in logs:

```
❌ Post Photo Error: Connection refused
```

**Check**:

- Database is running on Render
- DB_HOST, DB_NAME, DB_USER, DB_PASSWORD are correct
- Database accepts connections from your service

## 📊 Quick Debug Commands

### Check environment in Render:

```bash
# Add this temporarily to your route to debug:
print('ENV CLOUDINARY_CLOUD_NAME: ${Platform.environment['CLOUDINARY_CLOUD_NAME']}');
print('ENV CLOUDINARY_API_KEY: ${Platform.environment['CLOUDINARY_API_KEY']}');
```

### View all environment variables:

```bash
# In Render logs, add this to see all env vars (temporarily):
print('All env vars: ${Platform.environment}');
```

## 🔄 After Every Fix:

1. Commit changes: `git add . && git commit -m "Fix cloudinary upload"`
2. Push to Git: `git push`
3. Wait for Render auto-deploy (or trigger manual deploy)
4. Check logs during deployment
5. Test API again

## 📱 Contact Support

If still not working after all checks:

1. **Share Render Logs**: Copy the full log output when you make a request
2. **Share Postman Response**: The exact JSON error response
3. **Share Environment**: List of environment variable names (not values!)

This will help diagnose the exact issue quickly.
