# SQL Server – CursorAiAccess Login

**Purpose**: Login used for Cursor AI / development access to the local SQL Server (schema comparison, T-SQL port work, MICS databases).

---

## Connection details

| Item       | Value            |
|-----------|------------------|
| **Server** | `DESKTOP-EEUSAQH` |
| **Login**  | `CursorAiAccess`  |
| **Password** | `Cack31415`    |

**Example (sqlcmd):**
```bash
sqlcmd -S DESKTOP-EEUSAQH -U CursorAiAccess -P Cack31415 -d <DatabaseName> -Q "SELECT 1;"
```

---

## Databases visible to this login

- **micsprod** – MICS production
- **MicsAI**
- **MicsMin**
- **RemicsDev** – MICS dev
- GodsGame
- AI, Galaxy, GalaxyTwo, DBA_Training, DBA_Training2
- master, model, msdb, tempdb (system)

---

## Notes

- Confirmed working: January 2026.
- Use for read-only or dev work (schema comparison, T-SQL port); avoid production writes unless intended.
- Keep this file out of public repositories if the repo is shared.

---

*Last updated: January 2026*
