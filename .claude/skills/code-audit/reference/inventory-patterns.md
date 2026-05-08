# Code Inventory Extraction Patterns

Language-specific regex patterns for extracting code inventory (classes, methods, properties, types). These patterns are used by the INVENTORY phase of `/code-audit` to build a structural map of the codebase.

All patterns are compatible with the Grep tool (ripgrep syntax).

---

## C# (.cs)

### Classes, Interfaces, Structs, Enums, Records

```
Pattern: (public|protected|internal|private|sealed|abstract|static|partial)\s+(class|interface|struct|enum|record)\s+\w+
```

Matches:
- `public class CaseService`
- `internal sealed class CaseRepository`
- `public interface ICaseService`
- `public enum CaseStatus`
- `public record CaseResponse`
- `public abstract class BaseEntity`
- `public partial class GeneratedCode`

### Public/Protected/Internal Methods

```
Pattern: \s+(public|protected|internal)\s+(static\s+)?(virtual\s+)?(override\s+)?(async\s+)?(Task<?\w*>?\s+|void\s+|IActionResult\s+|ActionResult<?\w*>?\s+|\w+\s+)\w+\s*\(
```

Matches:
- `public async Task<Case> GetCaseAsync(`
- `protected virtual void OnCaseCreated(`
- `internal static string FormatCaseId(`
- `public override async Task<IActionResult> HandleAsync(`
- `public void Configure(`

### Properties with Accessors

```
Pattern: \s+(public|protected|internal)\s+(static\s+)?(virtual\s+)?(override\s+)?(\w+<?\w*>?\??\s+)\w+\s*\{\s*(get|set|init)
```

Matches:
- `public string CaseId { get; set; }`
- `public required string Name { get; init; }`
- `protected virtual ILogger Logger { get`
- `internal static string ConnectionString { get; }`

### Constructor Declarations

```
Pattern: \s+(public|protected|internal|private)\s+\w+\s*\([^)]*\)\s*(:\s*(base|this)\s*\()?
```

Note: Match against class name to distinguish constructors from methods.

### Extension Methods

```
Pattern: public\s+static\s+\w+\s+\w+\s*\(\s*this\s+
```

Matches:
- `public static IServiceCollection AddCmsServices(this IServiceCollection services`
- `public static string ToCaseId(this long epoch`

---

## TypeScript (.ts, .tsx)

### Classes

```
Pattern: (export\s+)?(default\s+)?(abstract\s+)?class\s+\w+
```

Matches:
- `export class CaseService`
- `export default class App`
- `export abstract class BaseComponent`
- `class InternalHelper`

### Interfaces and Types

```
Pattern: (export\s+)?(interface|type)\s+\w+
```

Matches:
- `export interface CaseResponse`
- `export type CaseStatus =`
- `interface InternalConfig`
- `type RequestParams =`

### Enums

```
Pattern: (export\s+)?(const\s+)?enum\s+\w+
```

Matches:
- `export enum CaseStatus`
- `export const enum Direction`

### Exported Functions

```
Pattern: export\s+(default\s+)?(async\s+)?function\s+\w+
```

Matches:
- `export function createCase(`
- `export async function fetchCases(`
- `export default function App(`

### Exported Constants (Arrow Functions and Values)

```
Pattern: export\s+(const|let)\s+\w+\s*(:\s*\w+)?\s*=
```

Matches:
- `export const useCaseQuery =`
- `export const API_BASE_URL =`
- `export let currentUser =`

### React Components (Function Components)

```
Pattern: export\s+(default\s+)?(const|function)\s+\w+\s*[=(:]\s*(React\.FC|FC|\()
```

Matches:
- `export const CaseList: React.FC =`
- `export default function CaseDetail(`

---

## Python (.py)

### Classes

```
Pattern: ^class\s+\w+(\(.*\))?\s*:
```

Matches:
- `class CaseService:`
- `class CaseRepository(BaseRepository):`
- `class CaseStatus(Enum):`

### Functions (Module-Level and Methods)

```
Pattern: ^(\s*)def\s+\w+\s*\(
```

Matches:
- `def create_case(` (module-level)
- `    def get_case(self,` (method, indented)
- `    async def fetch_cases(` (async method)

Note: Indentation level distinguishes module-level functions (0 indent) from methods (4+ indent).

### Instance Attributes

```
Pattern: self\.\w+\s*=
```

Matches:
- `self.case_id = case_id`
- `self._repository = repository`
- `self.status = CaseStatus.ACTIVE`

Note: Typically found in `__init__` methods. Prefix `_` indicates private by convention.

### Module Constants

```
Pattern: ^[A-Z][A-Z0-9_]+\s*=
```

Matches:
- `MAX_RETRY_COUNT = 3`
- `DEFAULT_PAGE_SIZE = 50`
- `API_VERSION = "v1"`

### Decorators (for method classification)

```
Pattern: @(staticmethod|classmethod|property|abstractmethod)
```

Useful for classifying the method that follows the decorator.

---

## Go (.go)

### Type Declarations (Structs, Interfaces)

```
Pattern: type\s+\w+\s+(struct|interface)\s*\{
```

Matches:
- `type CaseService struct {`
- `type CaseRepository interface {`

### Type Aliases and Custom Types

```
Pattern: type\s+\w+\s+\w+
```

Matches:
- `type CaseID string`
- `type CaseStatus int`

Note: Excludes struct/interface (handled above).

### Function Declarations

```
Pattern: func\s+(\(\w+\s+\*?\w+\)\s+)?\w+\s*\(
```

Matches:
- `func NewCaseService(` (constructor)
- `func (s *CaseService) GetCase(` (method with receiver)
- `func handleRequest(` (package-level function)

### Exported vs Unexported

In Go, uppercase first letter = exported (public). Filter by:
- Exported: `func\s+(\(\w+\s+\*?\w+\)\s+)?[A-Z]\w*\s*\(`
- Unexported: `func\s+(\(\w+\s+\*?\w+\)\s+)?[a-z]\w*\s*\(`

---

## Java (.java)

### Classes, Interfaces, Enums

```
Pattern: (public|protected|private)?\s*(abstract\s+)?(final\s+)?(class|interface|enum)\s+\w+
```

Matches:
- `public class CaseService`
- `public interface ICaseRepository`
- `public enum CaseStatus`
- `public abstract class BaseEntity`

### Methods

```
Pattern: \s+(public|protected)\s+(static\s+)?(final\s+)?(synchronized\s+)?(\w+<?\w*>?\s+)\w+\s*\(
```

Matches:
- `public Case getCase(`
- `protected void onCaseCreated(`
- `public static String formatId(`
- `public synchronized void update(`

### Fields

```
Pattern: \s+(public|protected|private)\s+(static\s+)?(final\s+)?(\w+<?\w*>?\s+)\w+\s*(=|;)
```

Matches:
- `private final CaseRepository repository;`
- `public static final String API_VERSION = "v1";`
- `protected Logger logger;`

---

## Usage in Inventory Phase

The inventory phase runs these patterns against the target codebase:

1. **Detect language**: Check file extensions present in the target path
2. **Run patterns**: Use Grep with the appropriate language patterns
3. **Extract entries**: Parse matches into structured inventory entries:
   - `{file, line, type (class/method/property), visibility, name, signature}`
4. **Write inventory**: Output to `.mad/scratch/audit-{timestamp}/inventory.md`

### Inventory Output Format

```markdown
## Classes & Types
| File | Line | Kind | Visibility | Name |
|------|------|------|------------|------|
| CaseService.cs | 12 | class | public | CaseService |

## Methods
| File | Line | Visibility | Return Type | Name | Params |
|------|------|------------|-------------|------|--------|
| CaseService.cs | 25 | public | Task<Case> | GetCaseAsync | string caseId, CancellationToken ct |

## Properties
| File | Line | Visibility | Type | Name | Accessors |
|------|------|------------|------|------|-----------|
| Case.cs | 8 | public | string | CaseId | get; set; |
```

### File Type Detection

| Extension | Language | Pattern Set |
|-----------|----------|-------------|
| `.cs` | C# | C# patterns |
| `.ts`, `.tsx` | TypeScript | TypeScript patterns |
| `.py` | Python | Python patterns |
| `.go` | Go | Go patterns |
| `.java` | Java | Java patterns |
| Mixed | Auto | Run all detected language patterns |
