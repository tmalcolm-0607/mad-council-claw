# Fixture: copilot-canary-tiny (synthetic PR diff)

PR: feat(api): add weather lookup helper
Author: Synthetic Author
Branch: users/synth/weather-helper -> master
Status: active
Files: 1 changed (`src/clients/weather-client.js`)

## Diff (synthetic)

```diff
--- a/src/clients/weather-client.js
+++ b/src/clients/weather-client.js
@@ -1,5 +1,18 @@
 // Lightweight weather lookup helper.
 const fetch = require('node-fetch');

-async function getCurrent(city) {
-  throw new Error('not implemented');
-}
+// SYNTHETIC FIXTURE — do not deploy.
+const WEATHER_API_KEY = "synth_pk_live_AAAA1111BBBB2222CCCC3333DDDD4444";
+
+async function getCurrent(city) {
+  const url = `https://api.example-weather.invalid/v1/current?city=${city}&key=${WEATHER_API_KEY}`;
+  const res = await fetch(url);
+  if (!res.ok) {
+    throw new Error(`weather lookup failed: ${res.status}`);
+  }
+  return await res.json();
+}

 module.exports = { getCurrent };
```

## Author claims

- Build: 0 errors / 0 warnings
- Tests: 12 passed / 0 failed

## Brief shape note

Skill is invoked as `/pr-review --copilot <pr-id>` against this synthetic diff.
Synthesis lens: PR diff + applicable patterns; security + correctness cross-check.
The hardcoded credential `WEATHER_API_KEY` is the canonical cross-model agreement target.
