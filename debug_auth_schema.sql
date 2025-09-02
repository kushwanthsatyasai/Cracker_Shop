-- Debug auth schema and constraints that might be causing user creation to fail
-- Run this in Supabase SQL Editor to check for issues

-- =============================================================================
-- 1. CHECK AUTH SCHEMA AND REQUIRED FIELDS
-- =============================================================================

-- Check auth.users table structure
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default,
  CASE 
    WHEN is_nullable = 'NO' AND column_default IS NULL THEN '⚠️  REQUIRED'
    WHEN is_nullable = 'NO' AND column_default IS NOT NULL THEN '✅ REQUIRED (has default)'
    ELSE '✅ OPTIONAL'
  END as status
FROM information_schema.columns 
WHERE table_schema = 'auth' 
  AND table_name = 'users'
ORDER BY ordinal_position;

-- =============================================================================
-- 2. CHECK FOR PROBLEMATIC CONSTRAINTS OR TRIGGERS
-- =============================================================================

-- Check constraints on auth.users
SELECT 
  constraint_name,
  constraint_type,
  table_name
FROM information_schema.table_constraints 
WHERE table_schema = 'auth' 
  AND table_name = 'users';

-- Check for any custom triggers on auth.users that might be failing
SELECT 
  trigger_name,
  event_manipulation,
  action_timing,
  action_statement
FROM information_schema.triggers 
WHERE event_object_schema = 'auth' 
  AND event_object_table = 'users';

-- =============================================================================
-- 3. TEST MINIMAL USER CREATION DIRECTLY
-- =============================================================================

-- Test if we can create a minimal user directly (this should work with service role)
-- This will help identify if the issue is with our Flutter code or database constraints

/*
-- UNCOMMENT AND RUN THIS TO TEST DIRECT CREATION:

INSERT INTO auth.users (
  id,
  email,
  created_at,
  updated_at,
  email_confirmed_at,
  confirmed_at
) VALUES (
  gen_random_uuid(),
  'direct_test@example.com',
  NOW(),
  NOW(),
  NOW(),
  NOW()
) RETURNING id, email, created_at;

-- Check if it was created
SELECT id, email, created_at, email_confirmed_at 
FROM auth.users 
WHERE email = 'direct_test@example.com';

-- Clean up test user
DELETE FROM auth.users WHERE email = 'direct_test@example.com';
*/

-- =============================================================================
-- 4. CHECK SUPABASE AUTH SETTINGS
-- =============================================================================

-- Check if there are any auth settings that might be blocking user creation
SELECT 
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM auth.users 
      WHERE email_confirmed_at IS NULL 
      LIMIT 1
    ) THEN '✅ Email confirmation not strictly required'
    ELSE 'ℹ️  All users have confirmed emails'
  END as email_confirmation_status;

-- =============================================================================
-- 5. CHECK RLS POLICIES ON AUTH SCHEMA (RARELY THE ISSUE, BUT WORTH CHECKING)
-- =============================================================================

-- Check if there are any RLS policies on auth.users
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies 
WHERE schemaname = 'auth';

-- =============================================================================
-- 6. CHECK FOR CUSTOM FUNCTIONS THAT MIGHT INTERFERE
-- =============================================================================

-- Check for any custom functions in auth schema
SELECT 
  routine_name,
  routine_type,
  specific_name
FROM information_schema.routines 
WHERE routine_schema = 'auth'
  AND routine_type = 'FUNCTION';

-- =============================================================================
-- 7. SUGGESTED DEBUGGING STEPS
-- =============================================================================

/*
Based on the results above, here's what to check:

1. If auth.users has unexpected required fields without defaults
2. If there are custom triggers that might be failing
3. If direct user creation works (uncomment test above)
4. If there are RLS policies blocking service role access

Common issues:
- Missing required fields in auth.users
- Custom triggers that fail on certain conditions
- RLS policies that don't account for service role
- Supabase instance configuration issues

Next steps:
1. Run this script and review results
2. Try the direct user creation test
3. If direct creation works, the issue is in Flutter code
4. If direct creation fails, the issue is database configuration
*/

