-- Safe User Creation RPC - Profile Only Approach
-- This avoids auth.users schema issues completely
-- Run this in your Supabase SQL Editor

-- Function to create user profile only (no auth.users manipulation)
CREATE OR REPLACE FUNCTION create_user_profile_safe(
  p_username TEXT,
  p_full_name TEXT,
  p_email TEXT,
  p_role TEXT DEFAULT 'biller',
  p_status TEXT DEFAULT 'active',
  p_admin_user_id UUID DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER  -- Run with elevated privileges
AS $$
DECLARE
  new_user_id UUID;
  existing_profile RECORD;
  result JSON;
BEGIN
  -- Validate admin permissions if admin_user_id is provided
  IF p_admin_user_id IS NOT NULL THEN
    SELECT role INTO existing_profile
    FROM profiles 
    WHERE id = p_admin_user_id;
    
    IF NOT FOUND OR existing_profile.role != 'admin' THEN
      RETURN json_build_object(
        'success', false,
        'error', 'Insufficient permissions. Admin access required.'
      );
    END IF;
  END IF;

  -- Validate required fields
  IF p_username IS NULL OR p_username = '' OR 
     p_full_name IS NULL OR p_full_name = '' OR
     p_email IS NULL OR p_email = '' THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Missing required fields: username, full_name, email'
    );
  END IF;

  -- Validate role
  IF p_role NOT IN ('admin', 'biller') THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Invalid role. Must be "admin" or "biller"'
    );
  END IF;

  -- Check if username already exists
  SELECT id INTO existing_profile
  FROM profiles 
  WHERE username = p_username;
  
  IF FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Username "' || p_username || '" already exists'
    );
  END IF;

  -- Check if email already exists
  SELECT id INTO existing_profile
  FROM profiles 
  WHERE email = p_email;
  
  IF FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Email "' || p_email || '" already exists'
    );
  END IF;

  -- Generate new UUID for user (this will be provided by auth creation later)
  new_user_id := gen_random_uuid();

  -- Return instructions for manual auth user creation
  result := json_build_object(
    'success', true,
    'message', 'Validation passed. Create auth user with this data and then call create_user_profile_with_id',
    'auth_data', json_build_object(
      'user_id', new_user_id,
      'email', p_email,
      'username', p_username,
      'full_name', p_full_name,
      'role', p_role
    ),
    'next_step', 'Call create_user_profile_with_id(' || new_user_id || ', ...)'
  );

  RETURN result;

EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Validation error: ' || SQLERRM
    );
END;
$$;

-- Function to create profile with specific user ID (after auth user is created)
CREATE OR REPLACE FUNCTION create_user_profile_with_id(
  p_user_id UUID,
  p_username TEXT,
  p_full_name TEXT,
  p_email TEXT,
  p_role TEXT DEFAULT 'biller',
  p_status TEXT DEFAULT 'active',
  p_admin_user_id UUID DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  existing_profile RECORD;
  result JSON;
BEGIN
  -- Validate admin permissions if admin_user_id is provided
  IF p_admin_user_id IS NOT NULL THEN
    SELECT role INTO existing_profile
    FROM profiles 
    WHERE id = p_admin_user_id;
    
    IF NOT FOUND OR existing_profile.role != 'admin' THEN
      RETURN json_build_object(
        'success', false,
        'error', 'Insufficient permissions. Admin access required.'
      );
    END IF;
  END IF;

  -- Check if profile already exists
  SELECT id INTO existing_profile
  FROM profiles 
  WHERE id = p_user_id;
  
  IF FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Profile already exists for this user ID'
    );
  END IF;

  -- Check if username already exists
  SELECT id INTO existing_profile
  FROM profiles 
  WHERE username = p_username;
  
  IF FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Username "' || p_username || '" already exists'
    );
  END IF;

  -- Create profile entry
  INSERT INTO profiles (
    id,
    username,
    email,
    full_name,
    role,
    status,
    created_at,
    updated_at
  ) VALUES (
    p_user_id,
    p_username,
    p_email,
    p_full_name,
    p_role,
    p_status,
    NOW(),
    NOW()
  );

  -- Return success response
  result := json_build_object(
    'success', true,
    'message', 'User profile created successfully',
    'user', json_build_object(
      'id', p_user_id,
      'username', p_username,
      'email', p_email,
      'full_name', p_full_name,
      'role', p_role,
      'status', p_status,
      'created_at', NOW(),
      'updated_at', NOW()
    )
  );

  RETURN result;

EXCEPTION
  WHEN unique_violation THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Username or email already exists'
    );
  WHEN OTHERS THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Database error: ' || SQLERRM
    );
END;
$$;

-- Grant execute permission to authenticated users and service role
GRANT EXECUTE ON FUNCTION create_user_profile_safe(TEXT, TEXT, TEXT, TEXT, TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION create_user_profile_safe(TEXT, TEXT, TEXT, TEXT, TEXT, UUID) TO service_role;

GRANT EXECUTE ON FUNCTION create_user_profile_with_id(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION create_user_profile_with_id(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, UUID) TO service_role;

-- Example usage:
-- Step 1: Validate and get instructions
-- SELECT create_user_profile_safe('testuser', 'Test User', 'test@example.com', 'biller', 'active');

-- Step 2: Create auth user via Supabase Auth API (from Flutter)

-- Step 3: Create profile with auth user ID
-- SELECT create_user_profile_with_id('auth-user-id-here', 'testuser', 'Test User', 'test@example.com', 'biller', 'active');