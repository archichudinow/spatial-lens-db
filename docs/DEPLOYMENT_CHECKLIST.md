# Storage Update Deployment Checklist

**Implementation Date**: January 25, 2026  
**Status**: Ready for deployment

## Pre-Deployment

- [x] Database migrations created
  - [x] `20260125161000_add_project_name_field.sql`
  - [x] `20260125162000_consolidate_storage_buckets.sql`
- [x] Edge functions updated
  - [x] `save-recording-with-glb/index.ts`
  - [x] `save-recording/index.ts`
- [x] Client utilities created
  - [x] `supabase/storage-utils.ts`
- [x] Documentation complete
  - [x] STORAGE_UPDATE.md (design)
  - [x] STORAGE_IMPLEMENTATION.md (guide)
  - [x] STORAGE_IMPLEMENTATION_SUMMARY.md (summary)
  - [x] STORAGE_QUICK_REFERENCE.md (quick ref)
  - [x] README.md (updated)
- [x] Code review complete
- [x] No TypeScript/SQL errors

## Local Testing

- [ ] Start local Supabase instance
  ```bash
  supabase start
  ```

- [ ] Apply migrations
  ```bash
  supabase db reset
  ```

- [ ] Verify migrations applied successfully
  ```bash
  supabase migration list
  ```

- [ ] Test database functions
  ```sql
  -- Test project path generation
  SELECT get_project_storage_path('00000000-0000-0000-0000-000000000000');
  
  -- Test option model path
  SELECT generate_option_model_path(
    '00000000-0000-0000-0000-000000000000',
    '11111111-1111-1111-1111-111111111111',
    1234567890
  );
  ```

- [ ] Test edge functions locally
  ```bash
  supabase functions serve
  ```

- [ ] Create test project
  ```typescript
  const { data: project } = await supabase
    .from('projects')
    .insert({ name: 'Test Project' })
    .select()
    .single()
  ```

- [ ] Test option model upload
  ```bash
  curl -X POST http://localhost:54321/functions/v1/save-recording-with-glb \
    -H "Authorization: Bearer YOUR_ANON_KEY" \
    -F "projectId=PROJECT_ID" \
    -F "optionId=OPTION_ID" \
    -F "scenarioId=SCENARIO_ID" \
    -F "glbFile=@test.glb"
  ```

- [ ] Verify file in storage browser
  ```
  http://localhost:54323/project/default/storage/buckets/projects
  ```

- [ ] Verify hierarchical path structure
  - [ ] Path includes project name
  - [ ] Path follows documented structure
  - [ ] Timestamp is correct

## Staging Deployment

- [ ] Backup production database
  ```bash
  supabase db dump --linked > backup.sql
  ```

- [ ] Push migrations to staging
  ```bash
  supabase db push --project-ref STAGING_REF
  ```

- [ ] Deploy edge functions to staging
  ```bash
  supabase functions deploy save-recording --project-ref STAGING_REF
  supabase functions deploy save-recording-with-glb --project-ref STAGING_REF
  ```

- [ ] Verify staging functions
  - [ ] Check function logs
  - [ ] Test uploads via staging URL
  - [ ] Verify storage paths

- [ ] Test with staging client app
  - [ ] Create new project
  - [ ] Upload option model
  - [ ] Upload recording
  - [ ] Verify all files accessible

- [ ] Performance check
  - [ ] Upload speed acceptable
  - [ ] Path generation < 100ms
  - [ ] Database load normal

## Production Deployment

- [ ] Announce maintenance window (if needed)

- [ ] Push migrations to production
  ```bash
  supabase db push --project-ref PRODUCTION_REF
  ```

- [ ] Verify migrations applied
  ```bash
  supabase migration list --project-ref PRODUCTION_REF
  ```

- [ ] Deploy edge functions to production
  ```bash
  supabase functions deploy save-recording --project-ref PRODUCTION_REF
  supabase functions deploy save-recording-with-glb --project-ref PRODUCTION_REF
  ```

- [ ] Verify production functions
  - [ ] Test with production anon key
  - [ ] Check function logs for errors
  - [ ] Monitor error rates

- [ ] Smoke tests on production
  - [ ] Create test project
  - [ ] Upload test files
  - [ ] Verify paths correct
  - [ ] Download and verify files
  - [ ] Delete test data

- [ ] Monitor for 24 hours
  - [ ] Watch error logs
  - [ ] Monitor storage usage
  - [ ] Check upload success rates
  - [ ] Verify no client errors

## Client App Updates

- [ ] Update client dependencies
  ```bash
  # Copy storage-utils.ts to client app
  cp supabase/storage-utils.ts ../client-app/src/lib/
  ```

- [ ] Update upload code
  - [ ] Replace direct storage calls with Edge Function calls
  - [ ] Update FormData payloads
  - [ ] Handle new response format

- [ ] Test client integration
  - [ ] Upload flows work
  - [ ] File downloads work
  - [ ] Error handling correct

- [ ] Deploy client app

## Data Migration (if existing files)

- [ ] Audit existing files
  ```sql
  SELECT bucket_id, name FROM storage.objects 
  WHERE bucket_id IN ('models', 'recordings', 'projects')
  ORDER BY created_at DESC;
  ```

- [ ] Create migration script
  - [ ] Download old files
  - [ ] Re-upload via edge functions
  - [ ] Update database records
  - [ ] Verify all files migrated

- [ ] Delete old files (after verification)
  ```sql
  -- After 30 days of successful operation
  DELETE FROM storage.objects WHERE bucket_id IN ('models', 'recordings');
  ```

## Rollback Plan

If critical issues occur:

1. **Revert Edge Functions**
   ```bash
   git revert <commit-hash>
   supabase functions deploy save-recording --project-ref PRODUCTION_REF
   supabase functions deploy save-recording-with-glb --project-ref PRODUCTION_REF
   ```

2. **Revert Migrations** (if necessary)
   ```sql
   -- Manual rollback - migrations are not automatically reversible
   -- Contact DBA or restore from backup
   ```

3. **Restore from backup** (last resort)
   ```bash
   supabase db reset --project-ref PRODUCTION_REF
   psql -d DATABASE_URL -f backup.sql
   ```

## Success Criteria

✅ All migrations applied without errors  
✅ Edge functions deployed and responding  
✅ Test uploads complete successfully  
✅ Hierarchical paths created correctly  
✅ Old functionality still works  
✅ No increase in error rates  
✅ Storage browser shows correct structure  
✅ Client apps integrate successfully  

## Post-Deployment

- [ ] Update documentation links
- [ ] Notify development team
- [ ] Update API documentation
- [ ] Schedule old bucket cleanup (30 days)
- [ ] Monitor metrics for 1 week
- [ ] Conduct retrospective

## Contacts

**Database**: [DBA contact]  
**DevOps**: [DevOps contact]  
**Backend**: [Backend team]  
**Frontend**: [Frontend team]  

## Notes

- Old `models` and `recordings` buckets remain for backward compatibility
- All new uploads use `projects` bucket
- Migration is non-breaking for read operations
- Function deployment is zero-downtime

---

**Deployed by**: _______________  
**Date**: _______________  
**Sign-off**: _______________
