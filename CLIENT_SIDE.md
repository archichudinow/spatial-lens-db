# Storage Structure Update - Client-Side Guide

## 📦 Backend Changes Deployed

The new hierarchical storage structure is now live in production. All file uploads now use organized, human-readable paths.

## 🔄 What Changed

**Old paths:**
```
abc-123/records/option_scenario_1234567890.glb
```

**New paths:**
```
spatial_analysis_abc-123/records/records_glb/option-id/scenario-id/processed_recording_1234567890.glb
```

### Storage Structure
```
projects/
  {project_name}_{project_id}/
    ├── options/{option_id}/model_{timestamp}.glb
    ├── records/
    │   ├── records_glb/{option_id}/{scenario_id}/processed_recording_{timestamp}.glb
    │   └── records_csv/{option_id}/{scenario_id}/raw_recording_{timestamp}.json
    └── others/
        ├── context_{timestamp}.glb
        └── heatmap_{timestamp}.glb
```

## 🎯 Required Client Updates

### 1. **Continue using Edge Functions** (no change)
All uploads must go through Edge Functions:
- `/functions/v1/save-recording`
- `/functions/v1/save-recording-with-glb`

### 2. **No client code changes needed!**
The Edge Functions handle all path generation. Your existing upload code should work as-is:

```typescript
const formData = new FormData()
formData.append('projectId', projectId)
formData.append('optionId', optionId)
formData.append('scenarioId', scenarioId)
formData.append('glbFile', glbFile)
formData.append('csvFile', csvFile) // optional

await fetch(`${SUPABASE_URL}/functions/v1/save-recording-with-glb`, {
  method: 'POST',
  headers: { 'Authorization': `Bearer ${anonKey}` },
  body: formData
})
```

**Response format remains the same:**
```json
{
  "success": true,
  "record": { ... },
  "glbUrl": "https://...spatial_analysis_abc-123/records/records_glb/.../processed_recording_123.glb",
  "rawUrl": "https://...spatial_analysis_abc-123/records/records_csv/.../raw_recording_123.json"
}
```

### 3. **File downloads** (no change)
Files remain publicly readable at their URLs. Existing URLs in the database continue to work.

### 4. **Direct storage uploads are blocked**
If you were uploading directly to storage (you shouldn't be), those will now fail. All uploads must go through Edge Functions.

## 📚 Optional: Client-Side Utilities

If you want to preview/validate paths client-side, copy this utility file to your project:
```
supabase/storage-utils.ts → your-client-app/src/lib/storage-utils.ts
```

Then use it like:
```typescript
import { generateStoragePath } from './lib/storage-utils'

// Preview what path will be generated
const { bucket, path } = generateStoragePath('record', 'processed_recording', {
  projectId: 'abc-123',
  projectName: 'Spatial Analysis',
  optionId: 'opt-456',
  scenarioId: 'scn-789'
})

console.log(bucket) // "projects"
console.log(path)   // "spatial_analysis_abc-123/records/records_glb/opt-456/scn-789/processed_recording_1234567890.glb"

// Note: Preview only! Actual upload still goes through Edge Function
```

### Available Utility Functions

```typescript
// Generate paths for different entity types
generateStoragePath(entityType, fileType, context, timestamp?)

// Specific path generators
generateOptionModelPath(context, timestamp?)
generateRecordGlbPath(context, timestamp?)
generateRecordRawPath(context, extension?, timestamp?)
generateProjectOtherPath(context, fileType, timestamp?)

// Parse existing paths
parseStoragePath(path: string)

// Get project folder name
getProjectStoragePath(projectName: string, projectId: string)
```

## 🧪 Testing Checklist

Test your upload flows:

- [ ] **Create new project** - verify it works
- [ ] **Upload option model** - check file appears in storage
- [ ] **Upload recording with GLB** - verify hierarchical path
- [ ] **Upload recording with CSV/JSON** - verify both files upload
- [ ] **Download files** - confirm URLs work
- [ ] **View files in Supabase Storage Browser** - verify organized structure
- [ ] **Check database records** - URLs should be stored correctly

### Test Upload Script

```typescript
// Test upload
async function testUpload() {
  const formData = new FormData()
  formData.append('projectId', 'YOUR_PROJECT_ID')
  formData.append('optionId', 'YOUR_OPTION_ID')
  formData.append('scenarioId', 'YOUR_SCENARIO_ID')
  formData.append('glbFile', testGlbFile)
  formData.append('durationMs', '5000')
  formData.append('deviceType', 'pc')
  
  const response = await fetch(
    'https://YOUR_PROJECT.supabase.co/functions/v1/save-recording-with-glb',
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${SUPABASE_ANON_KEY}`
      },
      body: formData
    }
  )
  
  const result = await response.json()
  console.log('Upload result:', result)
  
  if (result.success) {
    console.log('✅ GLB URL:', result.glbUrl)
    console.log('✅ Raw URL:', result.rawUrl)
  } else {
    console.error('❌ Upload failed:', result.error)
  }
}
```

## 📖 Documentation

Full documentation available in the database repository:

- **[STORAGE_QUICK_REFERENCE.md](STORAGE_QUICK_REFERENCE.md)** - Developer quick reference
- **[STORAGE_IMPLEMENTATION.md](STORAGE_IMPLEMENTATION.md)** - Complete implementation guide
- **[STORAGE_VISUALIZATION.md](STORAGE_VISUALIZATION.md)** - Visual diagrams and flow charts
- **[supabase/storage-utils.ts](supabase/storage-utils.ts)** - TypeScript utility file

## 🔒 Security Notes

- **Public Read**: All files in `projects` bucket are publicly readable
- **Service-Role Write**: Only Edge Functions (service_role) can upload/delete
- **No Direct Uploads**: Client apps cannot upload directly to storage
- **Validation**: All uploads validated by Edge Functions before storage

## 💡 Benefits

This new structure provides:

✅ **Better Organization** - All project files grouped together  
✅ **Human-Readable** - Folder names include project names  
✅ **No Collisions** - Clear hierarchy prevents filename conflicts  
✅ **Easy Navigation** - Simple to find files in storage browser  
✅ **Easy Backup** - Download entire project folders  
✅ **Better Debugging** - Clear path structure for troubleshooting  

## ❓ Common Questions

### Q: Do I need to update my existing upload code?
**A:** No, if you're already using Edge Functions, no changes needed.

### Q: Will old file URLs still work?
**A:** Yes, existing URLs in your database will continue to work.

### Q: Can I upload directly to storage?
**A:** No, all uploads must go through Edge Functions for security and validation.

### Q: What if I need the file path before uploading?
**A:** Use the client-side utilities for preview, but actual path is generated server-side.

### Q: Do I need to migrate existing files?
**A:** No, old files work fine. New uploads use the new structure automatically.

### Q: How do I debug upload failures?
**A:** Check Edge Function logs in Supabase Dashboard → Functions → Logs

## 🐛 Troubleshooting

### Upload fails with 403 Forbidden
- ✅ Verify you're using Edge Function endpoint (not direct storage upload)
- ✅ Check your Authorization header includes valid anon key

### Upload succeeds but file not found
- ✅ Check the returned URL in response
- ✅ Verify project/option/scenario IDs are correct
- ✅ Check Supabase Storage Browser to see actual path

### File path looks wrong
- ✅ Verify project name is being sanitized correctly
- ✅ Check that all required IDs (projectId, optionId, scenarioId) are provided
- ✅ Review Edge Function logs for path generation details

## 📞 Support

- **Backend Issues**: Contact database/backend team
- **Edge Function Errors**: Check logs in Supabase Dashboard
- **Storage Browser**: https://supabase.com/dashboard/project/YOUR_PROJECT/storage/buckets/projects
- **Function Logs**: https://supabase.com/dashboard/project/YOUR_PROJECT/functions

---

## TL;DR

✅ Backend deployed  
✅ Your upload code needs **no changes**  
✅ Just test that uploads still work  
✅ Files are now better organized in storage  
✅ Optional: Copy `storage-utils.ts` for path preview utilities  

**Next Step**: Test your upload flows and verify they work correctly.
