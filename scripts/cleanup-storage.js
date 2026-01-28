#!/usr/bin/env node
/**
 * Storage Cleanup Script
 * 
 * Cleans up orphaned storage files and database records.
 * 
 * Usage:
 *   SUPABASE_SERVICE_KEY=your-key node cleanup-storage.js
 * 
 * Or set it in .env:
 *   SUPABASE_SERVICE_KEY=your-service-key
 */

const { createClient } = require('@supabase/supabase-js')

const supabaseUrl = process.env.SUPABASE_URL || 'https://piibdadcmkrmvbiapglz.supabase.co'
const supabaseKey = process.env.SUPABASE_SERVICE_KEY

if (!supabaseKey) {
  console.error('❌ SUPABASE_SERVICE_KEY environment variable is required')
  console.error('\nGet your service_role key from:')
  console.error('https://supabase.com/dashboard/project/piibdadcmkrmvbiapglz/settings/api')
  console.error('\nUsage:')
  console.error('  SUPABASE_SERVICE_KEY=your-key node cleanup-storage.js')
  process.exit(1)
}

const supabase = createClient(supabaseUrl, supabaseKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
})

async function cleanup() {
  console.log('🔍 Checking for orphaned storage files...\n')
  
  try {
    // Find orphaned files
    const { data, error } = await supabase.rpc('find_orphaned_storage_files')
    
    if (error) {
      console.error('❌ Error finding orphaned files:', error)
      return
    }
    
    const orphanedFiles = data?.orphaned_files || []
    
    if (orphanedFiles.length === 0) {
      console.log('✅ No orphaned files found! Storage is clean.')
      return
    }
    
    console.log(`📋 Found ${orphanedFiles.length} orphaned file(s):\n`)
    orphanedFiles.forEach((f, i) => {
      console.log(`  ${i + 1}. ${f.path}`)
      console.log(`     Type: ${f.entity_type}/${f.file_type}`)
      console.log(`     Entity ID: ${f.entity_id}`)
      console.log(`     Created: ${f.created_at}`)
      console.log('')
    })
    
    // Delete from storage
    const paths = orphanedFiles.map(f => f.path)
    console.log('🗑️  Deleting files from storage...')
    
    const { data: deleteData, error: deleteError } = await supabase.storage
      .from('projects')
      .remove(paths)
    
    if (deleteError) {
      console.error('❌ Error deleting from storage:', deleteError)
      console.error('Note: Some files may not exist in storage anymore')
    } else {
      console.log(`✅ Deleted ${paths.length} file(s) from storage\n`)
    }
    
    // Clean up database records
    console.log('🧹 Cleaning up database records...')
    const { data: cleanupData, error: cleanupError } = await supabase.rpc('cleanup_orphaned_upload_files')
    
    if (cleanupError) {
      console.error('❌ Error cleaning database:', cleanupError)
    } else {
      console.log(`✅ ${cleanupData.message}\n`)
      console.log(`📊 Summary:`)
      console.log(`   - Storage files deleted: ${paths.length}`)
      console.log(`   - Database records cleaned: ${cleanupData.deleted_records}`)
    }
    
    console.log('\n✨ Cleanup complete!')
    
  } catch (err) {
    console.error('❌ Unexpected error:', err)
    process.exit(1)
  }
}

// Run cleanup
cleanup()
  .then(() => process.exit(0))
  .catch(err => {
    console.error(err)
    process.exit(1)
  })
