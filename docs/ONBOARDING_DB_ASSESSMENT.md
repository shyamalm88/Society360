# Assessment Report: Database & Service Changes for Society Onboarding

**Date:** 2025-12-01
**Author:** Claude Code
**Status:** Draft for Review

---

## 1. Current Database Schema

### `blocks` table (current)
| Column | Type | Description |
|--------|------|-------------|
| id | uuid | Primary key |
| complex_id | uuid | FK to complexes |
| name | text | Block name (A, B, etc.) |
| created_at | timestamptz | Creation timestamp |

### `flats` table (current)
| Column | Type | Description |
|--------|------|-------------|
| id | uuid | Primary key |
| block_id | uuid | FK to blocks |
| flat_number | text | e.g., "101", "A-201" |
| unit_type | text | simplex, duplex, etc. |
| bhk | smallint | 1, 2, 3, etc. |
| square_feet | integer | Area |
| parking_slots | integer | Number of parking slots |
| is_active | boolean | Soft delete flag |
| created_at | timestamptz | Creation timestamp |

### Migration 009 (pending) adds:
- `has_service_quarter` (boolean)
- `has_covered_parking` (boolean)
- `bhk` changed to text (for "1.5", "2.5")

---

## 2. What Mobile Apps Currently Use

### Guard App (`society360_guard`)

**Models used:**
```dart
class Block {
  final String id;
  final String name;
  final List<Flat> flats;
}

class Flat {
  final String id;
  final String number;       // ← Uses flat_number from DB
  final String? residentName; // ← Joined from flat_occupancies
}
```

**API consumed:** `GET /blocks`, `GET /flats`
- Only uses: `id`, `name`, `flat_number`, `resident_name`
- Does NOT use: `unit_type`, `bhk`, `square_feet`, `parking_slots`

### Resident App (`society360_resident`)

**Models used:**
```dart
class Block {
  final String id;
  final String name;
  final String societyId;
  final int totalFlats;
  final int floors;      // ← NOT in current DB!
}

class Flat {
  final String id;
  final String number;
  final String blockId;
  final int floor;       // ← NOT in current DB!
  final String type;     // Uses bhk
  final bool isOccupied;
  final String? ownerName;
}
```

---

## 3. Gap Analysis

### What's Missing in DB for Our Features

| Feature | Current DB | Required Change |
|---------|------------|-----------------|
| **Structure Type** (apartment/villa/rowhouse) | Not in `blocks` | ADD `structure_type` to blocks |
| **Floor Number** per flat | Not stored | ADD `floor` to flats |
| **Floor Count** per block | Not stored | ADD `floor_count` to blocks (optional, for display) |
| **Units per Floor** | Not stored | ADD `units_per_floor` to blocks (optional) |
| **Villa/Plot Number** | Uses flat_number | No change needed (flat_number works) |

### Current vs Required Hierarchy

```
CURRENT HIERARCHY:
Society → Complex → Block → Flat

FOR VILLAS:
Society → Complex → "Villa Section" (block) → Villa units (flats with floor=null)

FOR APARTMENTS:
Society → Complex → Block → Flats (with floor numbers)
```

---

## 4. Impact Analysis on Mobile Apps

### Guard App - **NO IMPACT** ✅

| Change | Impact |
|--------|--------|
| Add `structure_type` to blocks | None - not used in guard app |
| Add `floor` to flats | None - not used in guard app |
| Add `floor_count` to blocks | None - not used in guard app |
| Change `bhk` to text | None - not used in guard app |
| Add villa support | **Works automatically** - villas appear as flats with names like "Villa 1" |

The guard app only needs:
- Block name (for display)
- Flat number (for destination selection)
- Resident name (for confirmation)

**All existing functionality will work unchanged.**

### Resident App - **MINOR IMPACT** ⚠️

| Change | Impact |
|--------|--------|
| Add `floor` to flats | **POSITIVE** - The Dart model already expects `floor`, currently this would be null/0 |
| Add `structure_type` to blocks | None - not currently used |
| Villa support | Works - flat_number displays villa number |

The resident app's `Flat` model has `floor: int` but the current API doesn't return it. Adding the `floor` column would:
- **Fix** the resident app (currently likely shows 0 for all floors)
- Need to ensure the API returns the floor column

---

## 5. Recommended Database Changes

### Migration 010: Structure Types & Floor Tracking

```sql
-- For BLOCKS table
ALTER TABLE blocks ADD COLUMN IF NOT EXISTS structure_type text DEFAULT 'apartment';
-- Values: 'apartment', 'villa', 'rowhouse', 'mixed'

-- For FLATS table
ALTER TABLE flats ADD COLUMN IF NOT EXISTS floor text;
-- Can be: '1', '2', 'G', 'LG', null (for villas)
```

### What NOT to Change ❌

- **DO NOT** change `flat_number` column - it's the key identifier used everywhere
- **DO NOT** add separate villa tables - use existing structure with `structure_type` flag
- **DO NOT** make `floor` required - villas have null floors

---

## 6. API Changes Required

### Backend Route: `GET /blocks`

**Current returns:**
```json
{
  "id": "uuid",
  "complex_id": "uuid",
  "name": "Block A",
  "created_at": "timestamp"
}
```

**Should return (after migration):**
```json
{
  "id": "uuid",
  "complex_id": "uuid",
  "name": "Block A",
  "created_at": "timestamp",
  "structure_type": "apartment",
  "floor_count": 10,
  "units_per_floor": 4
}
```

### Backend Route: `GET /flats`

**Current returns:**
```json
{
  "id": "uuid",
  "block_id": "uuid",
  "flat_number": "101",
  "unit_type": "simplex",
  "bhk": "2",
  "square_feet": 1200,
  "parking_slots": 1,
  "is_active": true,
  "is_occupied": true,
  "resident_name": "John Doe",
  "occupancy_role": "owner"
}
```

**Should return (after migration):**
```json
{
  "id": "uuid",
  "block_id": "uuid",
  "flat_number": "101",
  "unit_type": "simplex",
  "bhk": "2",
  "square_feet": 1200,
  "parking_slots": 1,
  "is_active": true,
  "is_occupied": true,
  "resident_name": "John Doe",
  "occupancy_role": "owner",
  "floor": "1",
  "has_service_quarter": false,
  "has_covered_parking": true
}
```

---

## 7. Implementation Plan

### Phase 1: Safe Database Changes (No App Impact)

1. Run migration 009 (has_service_quarter, has_covered_parking, bhk→text)
2. Create migration 010:
   - Add `structure_type` to blocks (default 'apartment')
   - Add `floor` to flats (nullable)
   - Add `floor_count` to blocks (nullable)
   - Add `units_per_floor` to blocks (nullable)

### Phase 2: Backend Updates

1. Update `POST /admin/societies/:id/structure` to save:
   - `structure_type` in blocks table
   - `floor` in flats table
   - All extended properties

2. Update `GET /flats` to return `floor` column

3. Update `GET /blocks` to return new columns (optional)

### Phase 3: Mobile App Updates (Optional)

1. Resident app already expects `floor` - will automatically work
2. Guard app doesn't need changes

---

## 8. Summary

| Aspect | Risk Level | Notes |
|--------|------------|-------|
| Guard App | **NONE** 🟢 | Uses only id, name, flat_number |
| Resident App | **LOW** 🟡 | Adding `floor` actually fixes expected behavior |
| Database | **LOW** 🟡 | All changes are additive (new columns with defaults) |
| Existing Data | **NONE** 🟢 | Defaults ensure backward compatibility |

### Safe to Proceed? ✅ YES

All proposed changes are:
- ✅ Additive (new columns, not removing/renaming)
- ✅ Have sensible defaults
- ✅ Don't break existing app functionality
- ✅ Villa/rowhouse units will work as "flats" with `floor=null`

---

## 9. Files to Update

### Database Migrations
- [x] `migrations/009_flat_extended_properties.sql` - Already created
- [ ] `migrations/010_structure_types.sql` - Need to create

### Backend Routes
- [ ] `src/routes/adminSocieties.js` - Update structure creation
- [ ] `src/routes/onboarding.js` - Update GET /blocks and GET /flats responses

### Admin Frontend
- [x] `src/pages/SocietyOnboarding.jsx` - Already updated with all features

---

## 10. Appendix: New Features Supported

After implementing these changes, the onboarding wizard will support:

1. **Structure Types:** Apartment, Villa, Row House, Mixed
2. **Naming Strategies:** Floor-Unit, Block Prefixed, Alphabetic Prefix, Sequential, Custom
3. **Floor Options:** Start from LG, G, or 1st floor
4. **Skip Unlucky Numbers:** 4 (Chinese), 13 (Western), custom
5. **Unit Properties:** BHK (1, 1.5, 2, 2.5...), Sq.Ft, Service Quarter, Covered Parking
6. **Unit Types:** Simplex, Duplex, Triplex, Penthouse, Villa, Row House, Studio
