# Quickstart Template: [FEATURE NAME]

**Feature**: [Feature name and spec link]
**Prerequisites**: [Required setup before running]

## Environment Setup

### 1. Install Dependencies

```bash
npm install
```

### 2. Start Database

```bash
docker compose up -d
```

### 3. Apply Migrations

```bash
npm run db:migrate
```

### 4. Load Seed Data (Optional)

```bash
npm run db:seed
```

## Running the Application

### Development Mode

```bash
npm run dev
```

Application runs at: http://localhost:5173

### Production Build

```bash
npm run build
npm run preview
```

## Verification Commands

### 1. Type Check

```bash
npm run typecheck
```

**Expected**: No errors

### 2. Lint Check

```bash
npm run lint
```

**Expected**: No errors or warnings

### 3. Unit Tests

```bash
npm test
```

**Expected**: All tests pass

### 4. E2E Tests

```bash
npm run test:e2e
```

**Expected**: All Playwright tests pass

## Feature-Specific Verification

### [Feature Step 1]

**Command**:

```bash
[command to run]
```

**Expected Output**:

```
[expected output or behavior]
```

### [Feature Step 2]

**Command**:

```bash
[command to run]
```

**Expected Output**:

```
[expected output or behavior]
```

## Troubleshooting

### Database Connection Failed

1. Verify Docker is running: `docker ps`
2. Check database logs: `docker compose logs db`
3. Verify connection string in environment

### Ollama Not Available

1. Verify Ollama is running: `curl http://localhost:11434/api/version`
2. Check model is available: `ollama list`
3. Pull required model: `ollama pull llama3.1:8b`

### Tests Failing

1. Run `npm run check` to verify code quality
2. Check for missing migrations: `npm run db:migrate`
3. Reset test database: `npm run db:reset:test`

## Clean Start

If you need to start fresh:

```bash
# Stop all containers
docker compose down -v

# Remove node_modules
rm -rf node_modules

# Reinstall and rebuild
npm install
docker compose up -d
npm run db:migrate
npm run db:seed
npm run dev
```
