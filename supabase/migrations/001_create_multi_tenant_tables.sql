-- =============================================
-- MIGRATION 001: MULTI-TENANT TABLES
-- Creates: gyms, branches, staff_profiles
-- =============================================

-- 1. GYMS TABLE
CREATE TABLE IF NOT EXISTS public.gyms (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    owner_user_id uuid REFERENCES auth.users(id),
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- 2. BRANCHES TABLE
CREATE TABLE IF NOT EXISTS public.branches (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    gym_id uuid NOT NULL REFERENCES public.gyms(id) ON DELETE CASCADE,
    name text NOT NULL,
    address text,
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    UNIQUE(gym_id, name)
);

-- 3. STAFF PROFILES TABLE
CREATE TABLE IF NOT EXISTS public.staff_profiles (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid UNIQUE NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    gym_id uuid NOT NULL REFERENCES public.gyms(id) ON DELETE CASCADE,
    branch_id uuid NOT NULL REFERENCES public.branches(id) ON DELETE CASCADE,
    role text NOT NULL CHECK (role IN ('owner_admin', 'branch_staff')),
    display_name text,
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Trigger: Ensure branch belongs to the specified gym
CREATE OR REPLACE FUNCTION validate_staff_branch_gym()
RETURNS trigger AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.branches 
        WHERE id = NEW.branch_id AND gym_id = NEW.gym_id
    ) THEN
        RAISE EXCEPTION 'branch_id does not belong to gym_id';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_validate_staff_branch_gym ON public.staff_profiles;
CREATE TRIGGER trg_validate_staff_branch_gym
    BEFORE INSERT OR UPDATE ON public.staff_profiles
    FOR EACH ROW EXECUTE FUNCTION validate_staff_branch_gym();

-- Indexes
CREATE INDEX IF NOT EXISTS idx_branches_gym_id ON public.branches(gym_id);
CREATE INDEX IF NOT EXISTS idx_staff_profiles_user_id ON public.staff_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_staff_profiles_branch_id ON public.staff_profiles(branch_id);
