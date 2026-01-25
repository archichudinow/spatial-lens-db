-- Migration: Allow Admins to Insert Records Directly
-- Description: Add INSERT policy for authenticated users (admins) on records table
--              Edge Functions are only for anonymous users submitting from simulation app

-- Add INSERT policy for authenticated users (admins)
CREATE POLICY "authenticated_insert_records"
  ON public.records
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

COMMENT ON POLICY "authenticated_insert_records" ON public.records IS 
  'Allows authenticated admins to insert records directly. Anonymous users must use Edge Functions.';
