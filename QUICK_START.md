# Quick Start Guide - Cracker Shop App

This guide will help you get the app running quickly for testing purposes.

## 🚀 Quick Setup (5 minutes)

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Update Supabase Configuration
Edit `lib/config/supabase_config.dart` and replace with your credentials:

```dart
class SupabaseConfig {
  static const String url = 'https://your-project-id.supabase.co';
  static const String anonKey = 'your-anon-key-here';
  static const String serviceRoleKey = 'your-service-role-key-here';
}
```

### 3. Run the App
```bash
flutter run
```

## 🔧 If You Don't Have Supabase Yet

### Option 1: Create Supabase Project (Recommended)
1. Go to [supabase.com](https://supabase.com)
2. Sign up and create a new project
3. Follow the setup in [SUPABASE_SETUP.md](SUPABASE_SETUP.md)

### Option 2: Use Mock Data (For Testing Only)
If you want to test the UI without setting up Supabase:

1. **Temporarily modify the services to return mock data**
2. **Test the UI and navigation**
3. **Set up Supabase later for full functionality**

## 🧪 Testing the App

### Test User Credentials
After setting up Supabase, create a test user:

1. **In Supabase Dashboard → Authentication → Users**
   - Add user with email: `test@example.com`
   - Password: `password123`

2. **In SQL Editor, create profile:**
```sql
INSERT INTO public.profiles (id, username, full_name, role, status)
VALUES (
  (SELECT id FROM auth.users WHERE email = 'test@example.com'),
  'testuser',
  'Test User',
  'admin',
  'active'
);
```

### Test Features
1. **Login** with your test credentials
2. **Navigate** through different screens
3. **Create** a test product
4. **Generate** a test bill
5. **Check** the dashboard

## 🐛 Common Quick Fixes

### Build Errors
```bash
flutter clean
flutter pub get
flutter run
```

### Connection Issues
- Check your Supabase URL and API keys
- Ensure your Supabase project is active
- Verify internet connectivity

### Authentication Issues
- Check if user exists in Supabase Auth
- Verify user profile in profiles table
- Ensure RLS policies are set up

## 📱 What You'll See

### Login Screen
- Beautiful gradient background
- Email/password fields
- Role selection

### Dashboard (Admin)
- Sales overview
- Quick actions
- User management
- Bill history

### Product Selection
- Product catalog
- Search and filtering
- Add to cart functionality

### Billing Screen
- Customer details form
- Bill items display
- Tax calculation
- Bill creation

## 🔄 Next Steps

After successful testing:

1. **Set up production database** with real data
2. **Configure email templates** in Supabase
3. **Set up additional providers** (Google, etc.)
4. **Customize the theme** and branding
5. **Add more features** as needed

## 📞 Need Help?

- Check the [SUPABASE_SETUP.md](SUPABASE_SETUP.md) for detailed setup
- Review the [README.md](README.md) for comprehensive information
- Check Flutter console for error messages
- Verify Supabase Dashboard → Logs

---

**🎯 Goal: Get the app running in under 5 minutes for basic testing!**
