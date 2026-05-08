#!/usr/bin/env node
/**
 * Context Utilities
 * Shared functions for managing context.md files
 */

const fs = require('fs');
const path = require('path');

/**
 * Find the feature directory for the current branch
 * @param {string} repoRoot - Repository root path
 * @returns {string|null} - Feature directory path or null
 */
function findFeatureDir(repoRoot) {
  try {
    const specsDir = path.join(repoRoot, 'specs');
    if (!fs.existsSync(specsDir)) return null;

    const dirs = fs.readdirSync(specsDir, { withFileTypes: true })
      .filter(d => d.isDirectory() && /^\d+-/.test(d.name))
      .map(d => d.name);

    // Return first feature dir with context.md, or first feature dir
    for (const dir of dirs) {
      const contextPath = path.join(specsDir, dir, 'context.md');
      if (fs.existsSync(contextPath)) {
        return path.join(specsDir, dir);
      }
    }

    return dirs.length > 0 ? path.join(specsDir, dirs[0]) : null;
  } catch {
    return null;
  }
}

/**
 * Read context.md and parse sections
 * @param {string} contextPath - Path to context.md
 * @returns {object} - Parsed context object
 */
function readContext(contextPath) {
  try {
    if (!fs.existsSync(contextPath)) {
      return null;
    }
    const content = fs.readFileSync(contextPath, 'utf8');
    return {
      path: contextPath,
      content,
      lines: content.split('\n')
    };
  } catch {
    return null;
  }
}

/**
 * Get next failure ID from context
 * @param {string} content - Context.md content
 * @returns {string} - Next failure ID (e.g., 'F001')
 */
function getNextFailureId(content) {
  const matches = content.match(/\| F(\d+) \|/g) || [];
  if (matches.length === 0) return 'F001';

  const ids = matches.map(m => parseInt(m.match(/F(\d+)/)[1], 10));
  const maxId = Math.max(...ids);
  return `F${String(maxId + 1).padStart(3, '0')}`;
}

/**
 * Add a failure entry to context.md
 * @param {string} contextPath - Path to context.md
 * @param {object} failure - Failure details
 * @returns {boolean} - Success status
 */
function addFailure(contextPath, failure) {
  try {
    const context = readContext(contextPath);
    if (!context) return false;

    const { category, task, error, rootCause, fix } = failure;
    const date = new Date().toISOString().split('T')[0];
    const id = getNextFailureId(context.content);

    // Find the Failure Log table
    const lines = context.lines;
    let insertIndex = -1;

    for (let i = 0; i < lines.length; i++) {
      if (lines[i].includes('## Failure Log')) {
        // Find the table header row
        for (let j = i + 1; j < lines.length; j++) {
          if (lines[j].startsWith('| ID |') || lines[j].startsWith('|----')) {
            continue;
          }
          if (lines[j].startsWith('| ')) {
            // Insert before first data row if it's a placeholder
            if (lines[j].includes('No failures logged yet')) {
              lines[j] = `| ${id} | ${date} | ${category} | ${task} | ${error} | ${rootCause} | ${fix} |`;
              insertIndex = j;
              break;
            }
            insertIndex = j;
            break;
          }
          if (lines[j].trim() === '' || lines[j].startsWith('**')) {
            // Insert new row here
            insertIndex = j;
            break;
          }
        }
        break;
      }
    }

    if (insertIndex === -1) return false;

    // Insert the new failure entry
    const newRow = `| ${id} | ${date} | ${category} | ${task} | ${error} | ${rootCause} | ${fix} |`;
    if (!lines[insertIndex].includes(id)) {
      lines.splice(insertIndex, 0, newRow);
    }

    // Update pattern count if exists
    updatePatternCount(lines, category, error);

    // Write back
    fs.writeFileSync(contextPath, lines.join('\n'));
    return true;
  } catch (e) {
    console.error('Error adding failure:', e.message);
    return false;
  }
}

/**
 * Update pattern count in Failure Patterns Detected section
 * @param {string[]} lines - Context.md lines
 * @param {string} category - Failure category
 * @param {string} error - Error summary
 */
function updatePatternCount(lines, category, error) {
  // Simple pattern matching - look for similar errors in patterns table
  const patterns = {
    'API': ['404', '401', '500', 'CORS', 'prefix'],
    'TEST': ['mock', 'vi.mock', 'undefined', 'assertion'],
    'E2E': ['timeout', 'selector', 'page.route'],
    'DOCKER': ['connection refused', 'health', 'FRONTEND_URL'],
    'DB': ['relation', 'migration', 'connection'],
    'BUILD': ['compile', 'syntax', 'import'],
    'TYPE': ['type', 'TypeScript', 'ts-expect']
  };

  const errorLower = error.toLowerCase();
  let matchedPattern = null;

  for (const [pat, keywords] of Object.entries(patterns)) {
    if (keywords.some(kw => errorLower.includes(kw.toLowerCase()))) {
      matchedPattern = pat;
      break;
    }
  }

  if (!matchedPattern) matchedPattern = category;

  // Find and update pattern count
  for (let i = 0; i < lines.length; i++) {
    if (lines[i].includes('### Failure Patterns Detected')) {
      for (let j = i + 1; j < lines.length; j++) {
        if (lines[j].startsWith('| ') && lines[j].includes(matchedPattern)) {
          // Increment count
          const countMatch = lines[j].match(/\| (\d+)\+? \|/);
          if (countMatch) {
            const currentCount = parseInt(countMatch[1], 10);
            lines[j] = lines[j].replace(/\| \d+\+? \|/, `| ${currentCount + 1}+ |`);
          }
          break;
        }
        if (lines[j].startsWith('###') || lines[j].startsWith('## ')) {
          break;
        }
      }
      break;
    }
  }
}

/**
 * Add session log entry
 * @param {string} contextPath - Path to context.md
 * @param {string} skill - Skill name
 * @param {string} event - Event type
 * @param {string} details - Event details
 */
function addSessionLog(contextPath, skill, event, details) {
  try {
    const context = readContext(contextPath);
    if (!context) return false;

    const lines = context.lines;
    const timestamp = new Date().toISOString().replace('T', ' ').slice(0, 16);

    for (let i = 0; i < lines.length; i++) {
      if (lines[i].includes('## Session Log')) {
        // Find table and add entry
        for (let j = i + 1; j < lines.length; j++) {
          if (lines[j].startsWith('| ') && !lines[j].includes('Time |') && !lines[j].includes('----')) {
            // Insert before first data row
            const newRow = `| ${timestamp} | ${skill} | ${event} | ${details} |`;
            lines.splice(j, 0, newRow);

            // Keep only last 20 entries
            let count = 0;
            for (let k = j; k < lines.length; k++) {
              if (lines[k].startsWith('| ') && !lines[k].includes('----')) {
                count++;
                if (count > 20) {
                  lines.splice(k, 1);
                  k--;
                }
              }
              if (lines[k].startsWith('*Events:')) break;
            }
            break;
          }
        }
        break;
      }
    }

    fs.writeFileSync(contextPath, lines.join('\n'));
    return true;
  } catch {
    return false;
  }
}

/**
 * Update current task state in context.md
 * @param {string} contextPath - Path to context.md
 * @param {object} taskState - Task state object
 */
function updateTaskState(contextPath, taskState) {
  try {
    const context = readContext(contextPath);
    if (!context) return false;

    const { taskId, status, description } = taskState;
    const lines = context.lines;

    for (let i = 0; i < lines.length; i++) {
      if (lines[i].includes('### Current Task')) {
        // Update the task state lines
        for (let j = i + 1; j < lines.length && j < i + 5; j++) {
          if (lines[j].startsWith('- **ID**:')) {
            lines[j] = `- **ID**: ${taskId}`;
          } else if (lines[j].startsWith('- **Status**:')) {
            lines[j] = `- **Status**: ${status}`;
          } else if (lines[j].startsWith('- **Description**:')) {
            lines[j] = `- **Description**: ${description}`;
          }
        }
        break;
      }
    }

    fs.writeFileSync(contextPath, lines.join('\n'));
    return true;
  } catch {
    return false;
  }
}

/**
 * Update gate results in context.md
 * @param {string} contextPath - Path to context.md
 * @param {object} gateResults - Gate results object
 */
function updateGateResults(contextPath, gateResults) {
  try {
    const context = readContext(contextPath);
    if (!context) return false;

    const { build, tests, coverage, docker, e2e, overall, attempt } = gateResults;
    const lines = context.lines;
    const timestamp = new Date().toISOString().replace('T', ' ').slice(0, 16);

    for (let i = 0; i < lines.length; i++) {
      if (lines[i].includes('## Gate Results')) {
        // Update the header line
        if (lines[i + 2] && lines[i + 2].startsWith('**Last Run**:')) {
          lines[i + 2] = `**Last Run**: ${timestamp} | **Attempt**: ${attempt || 1} | **Overall**: ${overall}`;
        }

        // Update individual gates
        for (let j = i + 1; j < lines.length; j++) {
          if (lines[j].includes('| Build |')) {
            lines[j] = `| Build | ${build?.result || '-'} | ${build?.notes || '-'} |`;
          } else if (lines[j].includes('| Tests |')) {
            lines[j] = `| Tests | ${tests?.result || '-'} | ${tests?.notes || '-'} |`;
          } else if (lines[j].includes('| Coverage |')) {
            lines[j] = `| Coverage | ${coverage?.result || '-'} | ${coverage?.notes || '-'} |`;
          } else if (lines[j].includes('| Docker |')) {
            lines[j] = `| Docker | ${docker?.result || '-'} | ${docker?.notes || '-'} |`;
          } else if (lines[j].includes('| E2E |')) {
            lines[j] = `| E2E | ${e2e?.result || '-'} | ${e2e?.notes || '-'} |`;
          }
          if (lines[j].startsWith('###') || lines[j].startsWith('## ')) break;
        }
        break;
      }
    }

    fs.writeFileSync(contextPath, lines.join('\n'));
    return true;
  } catch {
    return false;
  }
}

// Export for use in hooks and CLI
module.exports = {
  findFeatureDir,
  readContext,
  addFailure,
  addSessionLog,
  updateTaskState,
  updateGateResults,
  getNextFailureId
};

// CLI usage
if (require.main === module) {
  const args = process.argv.slice(2);
  const command = args[0];
  const repoRoot = process.cwd();

  const featureDir = findFeatureDir(repoRoot);
  if (!featureDir) {
    console.error('No feature directory found');
    process.exit(1);
  }

  const contextPath = path.join(featureDir, 'context.md');

  switch (command) {
    case 'add-failure':
      // Usage: node context-utils.js add-failure CATEGORY TASK "error" "root cause" "fix"
      if (args.length < 6) {
        console.error('Usage: add-failure CATEGORY TASK "error" "root cause" "fix"');
        process.exit(1);
      }
      const success = addFailure(contextPath, {
        category: args[1],
        task: args[2],
        error: args[3],
        rootCause: args[4],
        fix: args[5]
      });
      console.log(success ? 'Failure added' : 'Failed to add failure');
      break;

    case 'add-log':
      // Usage: node context-utils.js add-log SKILL EVENT "details"
      if (args.length < 4) {
        console.error('Usage: add-log SKILL EVENT "details"');
        process.exit(1);
      }
      addSessionLog(contextPath, args[1], args[2], args[3]);
      console.log('Log entry added');
      break;

    default:
      console.log('Commands: add-failure, add-log');
  }
}
