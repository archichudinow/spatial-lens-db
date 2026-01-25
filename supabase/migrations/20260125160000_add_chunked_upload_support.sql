-- Migration: Add chunked upload support
-- Description: Support splitting large files into chunks for reliable upload over slow connections
-- Date: 2026-01-25

-- =============================================================================
-- 1. CREATE UPLOAD SESSIONS TABLE
-- =============================================================================

CREATE TABLE upload_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Entity reference
  entity_type TEXT NOT NULL CHECK (entity_type IN ('project', 'option', 'record')),
  entity_id UUID NOT NULL,
  
  -- File metadata
  file_name TEXT NOT NULL,
  file_type TEXT NOT NULL,
  total_size BIGINT NOT NULL,
  mime_type TEXT,
  
  -- Chunking configuration
  chunk_size INTEGER DEFAULT 5242880, -- 5MB chunks
  total_chunks INTEGER NOT NULL,
  uploaded_chunks INTEGER[] DEFAULT ARRAY[]::INTEGER[], -- Array of completed chunk indices
  
  -- Final storage path
  final_path TEXT NOT NULL,
  
  -- Session status
  session_status TEXT DEFAULT 'active' CHECK (session_status IN ('active', 'completed', 'failed', 'expired')),
  
  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE,
  expires_at TIMESTAMP WITH TIME ZONE DEFAULT now() + INTERVAL '24 hours' NOT NULL,
  completed_at TIMESTAMP WITH TIME ZONE,
  
  -- Error tracking
  error_message TEXT,
  
  -- Indexes
  CONSTRAINT upload_sessions_entity_unique UNIQUE(entity_type, entity_id, file_name)
);

ALTER TABLE upload_sessions OWNER TO postgres;

CREATE INDEX idx_upload_sessions_entity ON upload_sessions(entity_type, entity_id);
CREATE INDEX idx_upload_sessions_status ON upload_sessions(session_status);
CREATE INDEX idx_upload_sessions_expires ON upload_sessions(expires_at);

COMMENT ON TABLE upload_sessions IS 'Tracks chunked upload sessions for large files';
COMMENT ON COLUMN upload_sessions.uploaded_chunks IS 'Array of chunk indices that have been successfully uploaded';
COMMENT ON COLUMN upload_sessions.chunk_size IS 'Size of each chunk in bytes (default 5MB)';

-- Trigger for updated_at
CREATE TRIGGER trigger_update_upload_sessions_updated_at
  BEFORE UPDATE ON upload_sessions
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- 2. FUNCTION: Mark chunk as completed
-- =============================================================================

CREATE OR REPLACE FUNCTION mark_chunk_completed(
  p_session_id UUID,
  p_chunk_index INTEGER
)
RETURNS JSON AS $$
DECLARE
  session_record upload_sessions%ROWTYPE;
  is_complete BOOLEAN;
BEGIN
  -- Get current session
  SELECT * INTO session_record FROM upload_sessions WHERE id = p_session_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Upload session not found: %', p_session_id;
  END IF;
  
  -- Check if session expired
  IF session_record.expires_at < now() THEN
    UPDATE upload_sessions SET session_status = 'expired' WHERE id = p_session_id;
    RAISE EXCEPTION 'Upload session expired';
  END IF;
  
  -- Add chunk to uploaded_chunks if not already there
  IF NOT (p_chunk_index = ANY(session_record.uploaded_chunks)) THEN
    UPDATE upload_sessions
    SET uploaded_chunks = array_append(uploaded_chunks, p_chunk_index),
        updated_at = now()
    WHERE id = p_session_id
    RETURNING * INTO session_record;
  END IF;
  
  -- Check if upload is complete
  is_complete := array_length(session_record.uploaded_chunks, 1) >= session_record.total_chunks;
  
  IF is_complete THEN
    UPDATE upload_sessions
    SET session_status = 'completed',
        completed_at = now()
    WHERE id = p_session_id;
  END IF;
  
  RETURN json_build_object(
    'session_id', p_session_id,
    'uploaded_chunks', array_length(session_record.uploaded_chunks, 1),
    'total_chunks', session_record.total_chunks,
    'is_complete', is_complete,
    'progress', (array_length(session_record.uploaded_chunks, 1)::FLOAT / session_record.total_chunks * 100)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION mark_chunk_completed(UUID, INTEGER) IS 'Marks a chunk as uploaded and checks if upload is complete';

-- =============================================================================
-- 3. FUNCTION: Get upload session status
-- =============================================================================

CREATE OR REPLACE FUNCTION get_upload_session_status(p_session_id UUID)
RETURNS JSON AS $$
DECLARE
  session_record upload_sessions%ROWTYPE;
  progress FLOAT;
BEGIN
  SELECT * INTO session_record FROM upload_sessions WHERE id = p_session_id;
  
  IF NOT FOUND THEN
    RETURN json_build_object('error', 'Session not found');
  END IF;
  
  progress := CASE 
    WHEN session_record.total_chunks > 0 
    THEN (array_length(session_record.uploaded_chunks, 1)::FLOAT / session_record.total_chunks * 100)
    ELSE 0
  END;
  
  RETURN json_build_object(
    'session_id', session_record.id,
    'entity_type', session_record.entity_type,
    'entity_id', session_record.entity_id,
    'file_name', session_record.file_name,
    'total_size', session_record.total_size,
    'uploaded_chunks', array_length(session_record.uploaded_chunks, 1),
    'total_chunks', session_record.total_chunks,
    'missing_chunks', (
      SELECT array_agg(chunk_num)
      FROM generate_series(0, session_record.total_chunks - 1) AS chunk_num
      WHERE NOT (chunk_num = ANY(session_record.uploaded_chunks))
    ),
    'progress', progress,
    'status', session_record.session_status,
    'final_path', session_record.final_path,
    'expires_at', session_record.expires_at,
    'created_at', session_record.created_at
  );
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_upload_session_status(UUID) IS 'Returns detailed status of an upload session including missing chunks';

-- =============================================================================
-- 4. FUNCTION: Cleanup expired sessions
-- =============================================================================

CREATE OR REPLACE FUNCTION cleanup_expired_upload_sessions()
RETURNS JSON AS $$
DECLARE
  expired_count INTEGER;
BEGIN
  -- Mark expired sessions
  UPDATE upload_sessions
  SET session_status = 'expired'
  WHERE session_status = 'active'
    AND expires_at < now();
  
  GET DIAGNOSTICS expired_count = ROW_COUNT;
  
  -- Delete sessions expired more than 7 days ago
  DELETE FROM upload_sessions
  WHERE session_status = 'expired'
    AND expires_at < now() - INTERVAL '7 days';
  
  RETURN json_build_object(
    'expired_sessions', expired_count,
    'deleted_old_sessions', (SELECT COUNT(*) FROM upload_sessions WHERE session_status = 'expired')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION cleanup_expired_upload_sessions() IS 'Marks expired sessions and deletes old ones (7+ days old)';

-- =============================================================================
-- 5. RLS POLICIES FOR UPLOAD_SESSIONS
-- =============================================================================

ALTER TABLE upload_sessions ENABLE ROW LEVEL SECURITY;

-- Authenticated users can create sessions
CREATE POLICY "Authenticated users can create upload sessions"
ON upload_sessions FOR INSERT
TO authenticated
WITH CHECK (true);

-- Authenticated users can view their sessions
CREATE POLICY "Authenticated users can view upload sessions"
ON upload_sessions FOR SELECT
TO authenticated
USING (true);

-- Authenticated users can update sessions
CREATE POLICY "Authenticated users can update upload sessions"
ON upload_sessions FOR UPDATE
TO authenticated
USING (true);

-- Authenticated users can delete sessions
CREATE POLICY "Authenticated users can delete upload sessions"
ON upload_sessions FOR DELETE
TO authenticated
USING (true);

-- =============================================================================
-- 6. GRANT PERMISSIONS
-- =============================================================================

GRANT EXECUTE ON FUNCTION mark_chunk_completed(UUID, INTEGER) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_upload_session_status(UUID) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION cleanup_expired_upload_sessions() TO authenticated;
