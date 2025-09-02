-- Test the safe user creation approach
-- This tests the 3-step process: validation -> auth user -> profile

-- =============================================================================
-- 1. TEST VALIDATION STEP
-- =============================================================================

-- Test validation (should pass if username/email don't exist)
SELECT create_user_profile_safe(
  'safetestuser',
  'Safe Test User',
  'safetest@example.com',
  'biller',
  'active'
);

-- =============================================================================
-- 2. MANUALLY CREATE AUTH USER FOR TESTING
-- =============================================================================

-- Since we can't easily test the Auth Admin API from SQL,
-- let's create a test auth user manually to test the profile creation

-- First, let's see if we can create a minimal auth user
-- (This might still have schema issues, but let's try)
/*
INSERT INTO auth.users (
  id,
  email,
  created_at,
  updated_at
) VALUES (
  '12345678-1234-1234-1234-123456789012',
  'manualtest@example.com',
  NOW(),
  NOW()
);
*/

-- Alternative: Use an existing auth user ID for testing
-- Replace this with an actual existing auth user ID from your database
DO $$
DECLARE
  existing_auth_id UUID;
BEGIN
  -- Get an existing auth user ID
  SELECT id INTO existing_auth_id 
  FROM auth.users 
  LIMIT 1;
  
  IF existing_auth_id IS NOT NULL THEN
    RAISE NOTICE 'Found existing auth user ID: %', existing_auth_id;
  ELSE
    RAISE NOTICE 'No existing auth users found';
  END IF;
END $$;

-- =============================================================================
-- 3. TEST PROFILE CREATION WITH EXISTING AUTH ID
-- =============================================================================

-- Get an existing auth user ID that doesn't have a profile
SELECT au.id, au.email, p.id as profile_id
FROM auth.users au
LEFT JOIN profiles p ON p.id = au.id
WHERE p.id IS NULL
LIMIT 1;

-- Test profile creation with an existing auth user ID
-- Replace 'existing-auth-id-here' with an actual ID from the query above
/*
SELECT create_user_profile_with_id(
  'existing-auth-id-here',  -- Replace with actual UUID
  'profiletestuser',
  'Profile Test User',
  'profiletest@example.com',
  'biller',
  'active'
);
*/

-- =============================================================================
-- 4. CHECK CURRENT USERS
-- =============================================================================

-- Show all current users
SELECT 
  au.id,
  au.email,
  au.created_at as auth_created,
  p.username,
  p.full_name,
  p.role,
  p.status,
  p.created_at as profile_created,
  CASE 
    WHEN p.id IS NOT NULL THEN 'HAS PROFILE ✓'
    ELSE 'NO PROFILE ✗'
  END as profile_status
FROM auth.users au
LEFT JOIN profiles p ON p.id = au.id
ORDER BY au.created_at DESC
LIMIT 10;

-- =============================================================================
-- 5. CHECK FUNCTION EXISTENCE
-- =============================================================================

-- Verify our safe functions exist
SELECT routine_name, routine_type
FROM information_schema.routines 
WHERE routine_name IN ('create_user_profile_safe', 'create_user_profile_with_id')
ORDER BY routine_name;
