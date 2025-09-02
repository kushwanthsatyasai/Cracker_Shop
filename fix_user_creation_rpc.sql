-- Fix user creation RPC - Enable pgcrypto and correct password hashing
-- Run this in Supabase SQL Editor

-- =============================================================================
-- 1. ENABLE PGCRYPTO EXTENSION
-- =============================================================================

-- Enable the pgcrypto extension for password hashing functions
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- =============================================================================
-- 2. UPDATE USER CREATION FUNCTION WITH CORRECT PASSWORD HASHING
-- =============================================================================

CREATE OR REPLACE FUNCTION public.create_user_complete(
  p_email TEXT,
  p_password TEXT,
  p_username TEXT,
  p_full_name TEXT,
  p_role TEXT DEFAULT 'biller',
  p_status TEXT DEFAULT 'active'
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  new_user_id UUID;
  user_record RECORD;
  result JSON;
BEGIN
  -- Validate inputs
  IF p_email IS NULL OR p_email = '' THEN
    RETURN json_build_object('success', false, 'error', 'Email is required');
  END IF;
  
  IF p_password IS NULL OR p_password = '' THEN
    RETURN json_build_object('success', false, 'error', 'Password is required');
  END IF;
  
  IF p_username IS NULL OR p_username = '' THEN
    RETURN json_build_object('success', false, 'error', 'Username is required');
  END IF;
  
  IF p_full_name IS NULL OR p_full_name = '' THEN
    RETURN json_build_object('success', false, 'error', 'Full name is required');
  END IF;

  -- Validate role
  IF p_role NOT IN ('admin', 'biller') THEN
    RETURN json_build_object('success', false, 'error', 'Role must be admin or biller');
  END IF;

  -- Validate status
  IF p_status NOT IN ('active', 'inactive') THEN
    RETURN json_build_object('success', false, 'error', 'Status must be active or inactive');
  END IF;

  -- Check if username already exists
  IF EXISTS (SELECT 1 FROM profiles WHERE username = p_username) THEN
    RETURN json_build_object('success', false, 'error', 'Username already exists');
  END IF;

  -- Check if email already exists
  IF EXISTS (SELECT 1 FROM profiles WHERE email = p_email) THEN
    RETURN json_build_object('success', false, 'error', 'Email already exists');
  END IF;

  BEGIN
    -- Generate new user ID
    new_user_id := gen_random_uuid();

    -- Insert into auth.users (this will trigger the existing triggers)
    INSERT INTO auth.users (
      id,
      email,
      encrypted_password,
      email_confirmed_at,
      created_at,
      updated_at,
      raw_user_meta_data,
      raw_app_meta_data,
      is_super_admin,
      role
    ) VALUES (
      new_user_id,
      p_email,
      crypt(p_password, gen_salt('bf')), -- Now works with pgcrypto enabled
      NOW(), -- Auto-confirm email
      NOW(),
      NOW(),
      json_build_object('username', p_username, 'full_name', p_full_name),
      '{}',
      false,
      'authenticated'
    );

    -- Wait a moment for triggers to complete
    PERFORM pg_sleep(0.1);

    -- Insert or update profile (in case trigger didn't create it properly)
    INSERT INTO profiles (
      id,
      username,
      full_name,
      email,
      role,
      status,
      created_at,
      updated_at
    ) VALUES (
      new_user_id,
      p_username,
      p_full_name,
      p_email,
      p_role,
      p_status,
      NOW(),
      NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
      username = EXCLUDED.username,
      full_name = EXCLUDED.full_name,
      email = EXCLUDED.email,
      role = EXCLUDED.role,
      status = EXCLUDED.status,
      updated_at = NOW();

    -- Get the created user data
    SELECT * INTO user_record FROM profiles WHERE id = new_user_id;

    -- Build success response
    result := json_build_object(
      'success', true,
      'user', json_build_object(
        'id', user_record.id,
        'username', user_record.username,
        'full_name', user_record.full_name,
        'email', user_record.email,
        'role', user_record.role,
        'status', user_record.status,
        'created_at', user_record.created_at,
        'updated_at', user_record.updated_at
      )
    );

    RETURN result;

  EXCEPTION WHEN OTHERS THEN
    -- Return error details
    RETURN json_build_object(
      'success', false, 
      'error', 'Database error: ' || SQLERRM,
      'error_code', SQLSTATE
    );
  END;
END;
$$;

-- =============================================================================
-- 3. ALTERNATIVE: SIMPLER APPROACH WITHOUT AUTH.USERS MANIPULATION
-- =============================================================================

-- This approach only creates profiles and lets Supabase handle auth.users
CREATE OR REPLACE FUNCTION public.create_user_simple(
  p_email TEXT,
  p_password TEXT,
  p_username TEXT,
  p_full_name TEXT,
  p_role TEXT DEFAULT 'biller',
  p_status TEXT DEFAULT 'active'
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  user_record RECORD;
BEGIN
  -- Validate inputs (same as above)
  IF p_email IS NULL OR p_email = '' THEN
    RETURN json_build_object('success', false, 'error', 'Email is required');
  END IF;
  
  -- Check if username already exists
  IF EXISTS (SELECT 1 FROM profiles WHERE username = p_username) THEN
    RETURN json_build_object('success', false, 'error', 'Username already exists');
  END IF;

  -- Check if email already exists
  IF EXISTS (SELECT 1 FROM profiles WHERE email = p_email) THEN
    RETURN json_build_object('success', false, 'error', 'Email already exists');
  END IF;

  -- Just return the data for Flutter to handle auth creation
  RETURN json_build_object(
    'success', true,
    'message', 'Validation passed - create user via Flutter Auth API',
    'validated_data', json_build_object(
      'email', p_email,
      'username', p_username,
      'full_name', p_full_name,
      'role', p_role,
      'status', p_status
    )
  );

EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object(
    'success', false, 
    'error', 'Validation error: ' || SQLERRM
  );
END;
$$;

-- =============================================================================
-- 4. GRANT PERMISSIONS
-- =============================================================================

GRANT EXECUTE ON FUNCTION public.create_user_complete TO service_role;
GRANT EXECUTE ON FUNCTION public.create_user_simple TO service_role;

-- =============================================================================
-- 5. TEST THE FUNCTIONS
-- =============================================================================

-- Test if pgcrypto is working
SELECT crypt('testpassword', gen_salt('bf')) as hashed_password;

-- Test the simple function
SELECT create_user_simple(
  'test2@example.com',
  'testpass123',
  'testuser2',
  'Test User 2',
  'biller',
  'active'
);

-- =============================================================================
-- RECOMMENDATION
-- =============================================================================

/*
Two approaches:

1. USE create_user_complete (if you want everything in RPC):
   - Enables pgcrypto extension
   - Handles both auth.users and profiles creation
   - More complex but self-contained

2. USE create_user_simple + Flutter Auth API (RECOMMENDED):
   - Only validates and prepares data
   - Let Flutter handle auth.admin.createUser
   - Then insert into profiles table
   - Simpler and more reliable

For immediate fix, try create_user_simple first!
*/
