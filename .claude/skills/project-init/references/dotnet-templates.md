# .NET Project Templates

When `*.csproj` or `*.sln` files are detected, apply .NET-specific configuration.

## .editorconfig

Create `.editorconfig` with C# settings:

```ini
# EditorConfig for .NET
# https://editorconfig.org

root = true

[*]
indent_style = space
indent_size = 4
end_of_line = crlf
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true

[*.cs]
# Sort using directives
dotnet_sort_system_directives_first = true
dotnet_separate_import_directive_groups = false

# Namespace preferences
csharp_style_namespace_declarations = file_scoped:suggestion

# Braces
csharp_new_line_before_open_brace = all
csharp_new_line_before_else = true
csharp_new_line_before_catch = true
csharp_new_line_before_finally = true

# Indentation
csharp_indent_case_contents = true
csharp_indent_switch_labels = true

# Spacing
csharp_space_after_cast = false
csharp_space_after_keywords_in_control_flow_statements = true
csharp_space_between_method_declaration_parameter_list_parentheses = false
csharp_space_between_method_call_parameter_list_parentheses = false

# Expression-level preferences
csharp_prefer_simple_default_expression = true:suggestion
csharp_style_expression_bodied_methods = when_on_single_line:suggestion
csharp_style_expression_bodied_properties = true:suggestion
csharp_style_expression_bodied_accessors = true:suggestion

# Pattern matching
csharp_style_pattern_matching_over_is_with_cast_check = true:suggestion
csharp_style_pattern_matching_over_as_with_null_check = true:suggestion

# Null checking
csharp_style_throw_expression = true:suggestion
csharp_style_conditional_delegate_call = true:suggestion

# var preferences
csharp_style_var_for_built_in_types = true:suggestion
csharp_style_var_when_type_is_apparent = true:suggestion
csharp_style_var_elsewhere = true:suggestion

# Code quality
dotnet_diagnostic.CA1062.severity = warning
dotnet_diagnostic.CA1822.severity = suggestion

[*.{json,yml,yaml}]
indent_size = 2

[*.md]
trim_trailing_whitespace = false
```

## Directory.Build.props

Create `Directory.Build.props` in solution root:

```xml
<Project>
  <PropertyGroup>
    <!-- Treat warnings as errors in CI/CD -->
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>

    <!-- Enable nullable reference types -->
    <Nullable>enable</Nullable>

    <!-- Enable implicit usings -->
    <ImplicitUsings>enable</ImplicitUsings>

    <!-- Target framework (update as needed) -->
    <TargetFramework>net10.0</TargetFramework>

    <!-- Enable latest language features -->
    <LangVersion>latest</LangVersion>

    <!-- Generate documentation -->
    <GenerateDocumentationFile>true</GenerateDocumentationFile>

    <!-- Suppress XML comment warnings for non-public members -->
    <NoWarn>$(NoWarn);CS1591</NoWarn>
  </PropertyGroup>

  <!-- Code analysis settings -->
  <PropertyGroup>
    <EnableNETAnalyzers>true</EnableNETAnalyzers>
    <AnalysisLevel>latest</AnalysisLevel>
    <EnforceCodeStyleInBuild>true</EnforceCodeStyleInBuild>
  </PropertyGroup>
</Project>
```

## Directory.Build.targets (Optional)

Create `Directory.Build.targets` for build customization:

```xml
<Project>
  <PropertyGroup Condition="'$(Configuration)' == 'Release'">
    <!-- Optimize for release builds -->
    <Optimize>true</Optimize>
    <DebugType>embedded</DebugType>
  </PropertyGroup>
</Project>
```

## NuGet.config

Create `NuGet.config` for package sources:

```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <!-- Clear inherited sources to ensure explicit control -->
    <clear />

    <!-- Official NuGet.org feed -->
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" protocolVersion="3" />

    <!-- Private NuGet feed (update URL as needed) -->
    <!-- <add key="PrivateFeed" value="https://nuget.example.com/v3/index.json" /> -->
  </packageSources>

  <packageSourceMapping>
    <!-- Map all packages to nuget.org by default -->
    <packageSource key="nuget.org">
      <package pattern="*" />
    </packageSource>

    <!-- Map internal packages to private feed if needed -->
    <!-- <packageSource key="PrivateFeed">
      <package pattern="YourCompany.*" />
    </packageSource> -->
  </packageSourceMapping>
</configuration>
```

## .NET-specific .claudeignore additions

```
# .NET build outputs
bin/
obj/
*.dll
*.exe
*.pdb

# NuGet
*.nupkg
packages/

# User-specific files
*.user
*.suo

# Test results
TestResults/
*.trx

# Coverage
coverage/
*.coverage
*.coveragexml
```

## .NET CLAUDE.md Template

When initializing a .NET project, CLAUDE.md includes:

```markdown
## Available Commands

| Command | Description |
|---------|-------------|
| `dotnet build` | Build all projects |
| `dotnet test` | Run all tests |
| `dotnet test --filter "TestCategory=Unit"` | Run unit tests only |
| `dotnet test --filter "TestCategory=Integration"` | Run integration tests |
| `dotnet format` | Format code |

## Testing Framework

This project uses [MSTest/xUnit] with:
- NSubstitute for mocking
- FluentAssertions for readable assertions

See `.claude/rules/patterns/dotnet-testing.md` for patterns.

## Architecture

[Layered architecture per `.claude/rules/patterns/dotnet-architecture.md`]
```
