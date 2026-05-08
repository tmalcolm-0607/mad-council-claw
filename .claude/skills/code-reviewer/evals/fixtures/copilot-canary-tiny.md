# Fixture: copilot-canary-tiny (synthetic source diff)

Synthetic input for `/code-reviewer --copilot`. Target is an in-progress branch; no PR yet.

## Synthetic input artifact

Target: `src/repositories/UserRepository.ts` (in-progress branch)

## Diff (synthetic)

```diff
--- a/src/repositories/UserRepository.ts
+++ b/src/repositories/UserRepository.ts
@@ -1,8 +1,22 @@
 import { Pool } from 'pg';

 export class UserRepository {
   constructor(private readonly pool: Pool) {}

-  async findById(id: string) {
-    throw new Error('not implemented');
-  }
+  async findById(id: string) {
+    // SYNTHETIC FIXTURE — do not deploy.
+    const query = "SELECT id, email, role FROM users WHERE id = '" + id + "'";
+    const result = await this.pool.query(query);
+    return result.rows[0] ?? null;
+  }
+
+  async findByEmail(email: string) {
+    const query = `SELECT id, email, role FROM users WHERE email = '${email}'`;
+    const result = await this.pool.query(query);
+    return result.rows[0] ?? null;
+  }
 }
```

## Skill invocation

```
/code-reviewer --copilot src/repositories/UserRepository.ts
```

## Brief shape note

Synthesis lens: source diff vs. project patterns; security + style cross-check.
The string-concatenation SQL sinks in `findById` and `findByEmail` are the canonical
cross-model agreement target — both Opus and GPT should flag SQL injection.
