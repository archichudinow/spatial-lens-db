# Storage Structure Update

## ✅ What's New

Backend now uses organized, hierarchical storage paths:

**Structure:**
```
projects/{project_name}_{project_id}/
  ├── options/{option_id}/model_{timestamp}.glb
  ├── records/
  │   ├── records_glb/{option_id}/{scenario_id}/processed_recording_{timestamp}.glb
  │   └── records_csv/{option_id}/{scenario_id}/raw_recording_{timestamp}.json
  └── others/context_{timestamp}.glb, heatmap_{timestamp}.glb
```

## 🎯 Action Required: **NONE**

Your existing upload code works without changes. Edge Functions handle all path generation.

## 📝 Upload Code (unchanged)

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

**Response:**
```json
{
  "success": true,
  "record": { ... },
  "glbUrl": "https://.../spatial_analysis_abc-123/records/records_glb/.../processed_recording_123.glb",
  "rawUrl": "https://.../spatial_analysis_abc-123/records/records_csv/.../raw_recording_123.json"
}
```

## 🧪 Testing

- [ ] Upload recording → verify it works
- [ ] Check file URL in response → matches new structure
- [ ] Download file → URL works

## 📚 Optional: Client-Side Utilities

Copy `supabase/storage-utils.ts` to your project for path preview/validation:

```typescript
import { generateStoragePath } from './lib/storage-utils'

const { bucket, path } = generateStoragePath('record', 'processed_recording', {
  projectId: 'abc-123',
  projectName: 'Spatial Analysis',
  optionId: 'opt-456',
  scenarioId: 'scn-789'
})
// Preview only - actual upload still via Edge Function
```

## 🐛 Troubleshooting

**Upload fails (403):**
- Use Edge Function endpoint (not direct storage)
- Check Authorization header

**File not found:**
- Verify all IDs are correct
- Check Edge Function logs in Supabase Dashboard

## 📖 Detailed Docs

See `docs/` folder for complete documentation:
- `docs/STORAGE_QUICK_REFERENCE.md` - Developer quick reference
- `docs/STORAGE_IMPLEMENTATION.md` - Implementation guide
- `docs/STORAGE_VISUALIZATION.md` - Visual diagrams

---

**TL;DR:** No code changes needed. Test your uploads. Files now better organized.
