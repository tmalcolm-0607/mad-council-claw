#!/usr/bin/env node
/**
 * Hook: AutoRegisterArtifact
 * Purpose: Automatically register artifacts written to work-items directories
 * Event: PostToolUse (Write)
 *
 * When a file is written to .claude/work-items/<ID>/artifacts/<type>/,
 * this hook automatically registers it in the work item manifest.
 */

const { execSync } = require('child_process');
const path = require('path');
const fs = require('fs');
let resolveActiveWI;
try {
  ({ resolveActiveWI } = require('../../.mad/lib/resolve-active-wi'));
} catch {
  resolveActiveWI = () => ({ wiId: null });
}

function getActiveWorkItemId(projectRoot, data) {
  const { wiId } = resolveActiveWI(data, projectRoot);
  return wiId || null;
}

async function readStdin() {
  const chunks = [];
  for await (const chunk of process.stdin) {
    chunks.push(chunk);
  }
  return Buffer.concat(chunks).toString();
}

async function main() {
  try {
    const input = await readStdin();
    const data = JSON.parse(input);

    // Only process Write tool
    if (data.tool_name !== 'Write') {
      process.exit(0);
      return;
    }

    const filePath = data.tool_input?.file_path || '';

    // Check if writing to work-items artifacts directory
    // Pattern: .claude/work-items/<WI-ID>/artifacts/<type>/<filename>
    const artifactPattern = /[\\\/]\.claude[\\\/]work-items[\\\/](WI-[^\\\/]+)[\\\/]artifacts[\\\/]([^\\\/]+)[\\\/]/i;
    const match = filePath.match(artifactPattern);

    if (!match) {
      // Not an artifact path, skip
      process.exit(0);
      return;
    }

    const workItemId = match[1];
    const artifactType = match[2];
    const projectRoot = process.cwd();

    const activeWorkItemId = getActiveWorkItemId(projectRoot, data);
    const strict = process.env.WORK_ITEM_STRICT === '1';

    if (activeWorkItemId && activeWorkItemId !== workItemId) {
      const message = `[auto-register] Cross-work-item artifact write detected. Path work item '${workItemId}' does not match ACTIVE '${activeWorkItemId}'.`;
      console.error(message);

      if (strict) {
        process.exit(2);
        return;
      }

      process.exit(0);
      return;
    }

    // Get relative path from project root
    let relativePath = filePath;
    if (path.isAbsolute(filePath)) {
      relativePath = path.relative(projectRoot, filePath);
    }
    relativePath = relativePath.replace(/\\/g, '/');

    // Call work-item.ps1 to register the artifact
    const scriptPath = path.join(projectRoot, '.claude', 'scripts', 'work-item.ps1');

    if (fs.existsSync(scriptPath)) {
      try {
        execSync(
          `powershell -File "${scriptPath}" add-artifact "${artifactType}" "${relativePath}"`,
          {
            cwd: projectRoot,
            stdio: 'pipe',
            timeout: 5000
          }
        );

        // Output confirmation (visible in hook output)
        console.error(`[auto-register] Registered ${artifactType} artifact: ${relativePath}`);
      } catch (execError) {
        // Log but don't fail the write
        console.error(`[auto-register] Warning: Could not register artifact: ${execError.message}`);
      }
    }

    process.exit(0);
  } catch (error) {
    // Hook error - fail-open (advisory hook)
    console.error('[auto-register-artifact] FATAL ERROR:', error.message);
    console.error('[auto-register-artifact] Hook failed - continuing (advisory).');
    process.exit(0);
  }
}

main();
