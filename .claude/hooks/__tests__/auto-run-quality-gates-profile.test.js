/**
 * Tests for auto-run-quality-gates.js - Profile Selection
 *
 * SKIPPED 2026-05-02: tests reference an "intelligent profile selection"
 * feature (analyzeFilePatterns + detectChangedFilesProfile) that does not
 * exist in `.claude/hooks/auto-run-quality-gates.js` and is not referenced
 * by any caller, script, or hook. The source uses a simpler cooldown-based
 * model and runs Run-DotnetGates.ps1 unconditionally — there is no profile
 * dispatch path.
 *
 * The two functions appear nowhere in the codebase (verified via repo-wide
 * grep). The tests were either written for a planned feature that was
 * never implemented, or for a feature that was removed before the tests
 * were updated.
 *
 * Skipping (not deleting) per `.claude/rules/test-failure-protocol.md`
 * Step 3 Option C — preserves the test bodies as a contract spec if the
 * feature is later implemented. Re-enable by removing the `.skip` markers
 * once the source exports analyzeFilePatterns + detectChangedFilesProfile.
 */

const path = require('path');

// Import the module under test
const hookModule = require('../auto-run-quality-gates.js');

describe.skip('analyzeFilePatterns (profile selection feature not implemented in source)', () => {
  const { analyzeFilePatterns } = hookModule;

  test('returns "backend" for C# files only', () => {
    const files = [
      'src/Api/Controllers/GameController.cs',
      'src/Application/Services/GameService.cs',
      'tests/Application.Tests/GameServiceTests.cs',
    ];
    expect(analyzeFilePatterns(files)).toBe('backend');
  });

  test('returns "backend" for .csproj files', () => {
    const files = ['src/Api/Api.csproj'];
    expect(analyzeFilePatterns(files)).toBe('backend');
  });

  test('returns "backend" for .sln files', () => {
    const files = ['src/consumer-project.sln'];
    expect(analyzeFilePatterns(files)).toBe('backend');
  });

  test('returns "frontend" for TypeScript files only', () => {
    const files = [
      'frontend/src/App.tsx',
      'frontend/src/components/Button.tsx',
    ];
    expect(analyzeFilePatterns(files)).toBe('frontend');
  });

  test('returns "frontend" for CSS files only', () => {
    const files = ['frontend/src/index.css'];
    expect(analyzeFilePatterns(files)).toBe('frontend');
  });

  test('returns "frontend" for JS files in frontend/', () => {
    const files = ['frontend/vite.config.js'];
    expect(analyzeFilePatterns(files)).toBe('frontend');
  });

  test('returns "frontend" for HTML files in frontend/', () => {
    const files = ['frontend/index.html'];
    expect(analyzeFilePatterns(files)).toBe('frontend');
  });

  test('returns "frontend" for SCSS files in frontend/', () => {
    const files = ['frontend/src/styles/main.scss'];
    expect(analyzeFilePatterns(files)).toBe('frontend');
  });

  test('returns "frontend" for LESS files in frontend/', () => {
    const files = ['frontend/src/styles/theme.less'];
    expect(analyzeFilePatterns(files)).toBe('frontend');
  });

  test('returns "full" when both backend and frontend files changed', () => {
    const files = [
      'src/Api/Controllers/GameController.cs',
      'frontend/src/App.tsx',
    ];
    expect(analyzeFilePatterns(files)).toBe('full');
  });

  test('returns "backend" for empty file list', () => {
    expect(analyzeFilePatterns([])).toBe('backend');
  });

  test('returns "backend" for unrecognized files', () => {
    const files = [
      '.claude/hooks/auto-run-quality-gates.js',
      'CLAUDE.md',
      'README.md',
    ];
    expect(analyzeFilePatterns(files)).toBe('backend');
  });

  test('returns "backend" for tests/ .cs files', () => {
    const files = ['tests/Domain.Tests/EntityTests.cs'];
    expect(analyzeFilePatterns(files)).toBe('backend');
  });

  test('returns "full" for mixed .cs and .tsx files', () => {
    const files = [
      'src/Api/Controllers/Health/HealthController.cs',
      'tests/Integration.Tests/HealthTests.cs',
      'frontend/src/pages/Health.tsx',
      'frontend/src/components/StatusBadge.tsx',
    ];
    expect(analyzeFilePatterns(files)).toBe('full');
  });
});

describe.skip('detectChangedFilesProfile (profile selection feature not implemented in source)', () => {
  const { detectChangedFilesProfile } = hookModule;

  // This function depends on git and filesystem, so we test it exists
  // and returns a valid profile string
  test('returns a valid profile string', () => {
    const projectDir = path.resolve(__dirname, '..', '..', '..');
    const result = detectChangedFilesProfile(projectDir);
    expect(['backend', 'frontend', 'full']).toContain(result);
  });

  test('returns "backend" when projectDir does not exist', () => {
    const result = detectChangedFilesProfile('/nonexistent/path');
    expect(result).toBe('backend');
  });
});
