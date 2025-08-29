# Supabase User Setup for Real Authentication

## Step 1: Create Users in Supabase

You need to create users in your Supabase Auth dashboard or use SQL to insert them.

### Option A: Using Supabase Dashboard

1. Go to your [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project
3. Go to **Authentication** → **Users**
4. Click **"Add User"**
5. Create these test users:

**Admin User:**
- Email: `admin@crackershop.com`
- Password: `password123`
- Role: `admin`

**Biller User:**
- Email: `biller@crackershop.com`
- Password: `password123`
- Role: `biller`

### Option B: Using SQL (Recommended)

1. Go to your Supabase Dashboard
2. Navigate to **SQL Editor**
3. Run this SQL to create test users:

```sql
-- Insert test users into auth.users (if using SQL)
-- Note: You'll need to create these through the Auth dashboard first
-- Then run this to insert their profiles:

INSERT INTO profiles (id, email, full_name, role, status, created_at, updated_at)
VALUES 
  ('1', 'admin@crackershop.com', 'Admin User', 'admin', 'active', NOW(), NOW()),
  ('2', 'biller@crackershop.com', 'Biller User', 'biller', 'active', NOW(), NOW());
```

## Step 2: Test Authentication

1. **Restart the Flutter app** to ensure the new authentication settings are loaded
2. **Try logging in** with:
   - Email: `admin@crackershop.com`
   - Password: `password123`
   - Role: `admin`

## Step 3: Check Console Logs

The app now has detailed logging. Check the browser console (F12) for:
- `AuthService: Attempting Supabase sign in for [email]`
- `AuthService: Supabase response status: [status]`
- `AuthService: Supabase response body: [response]`

## Troubleshooting

### If authentication fails:

1. **Check Supabase URL and Key**: Verify they're correct in `lib/config/supabase_config.dart`
2. **Verify User Exists**: Check your Supabase Auth dashboard
3. **Check RLS Policies**: Make sure your profiles table has proper RLS policies
4. **Check Console Logs**: Look for detailed error messages

### Common Issues:

1. **"Invalid email or password"**: User doesn't exist in Supabase Auth
2. **"Profile not found"**: User exists in Auth but not in profiles table
3. **"Network error"**: Check your internet connection and Supabase URL
4. **CORS errors**: Add your localhost to Supabase allowed origins

### RLS Policy for Profiles Table:

Make sure your profiles table has this RLS policy:

```sql
CREATE POLICY "Users can view own profile" ON profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE USING (auth.uid() = id);
```

## Current Status

✅ **Real Supabase Authentication Enabled**
✅ **Mock Authentication Disabled**
✅ **Detailed Logging Added**
✅ **Error Handling Improved**

The app is now using real Supabase authentication instead of mock data! 