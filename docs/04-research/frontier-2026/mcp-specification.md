---
artifact-class: research-finding
source-tag: [R:frontier-2026]
confidence: high
wave: wave-001
lane: lane-a
date: 2026-05-07
sources:
  - https://modelcontextprotocol.io/specification/2025-11-25
---

# MCP — Specification (2025-11-25)

## Source
https://modelcontextprotocol.io/specification/2025-11-25 (fetched 2026-05-07)

## Load-bearing patterns

- **JSON-RPC 2.0 base protocol**: All MCP messages are JSON-RPC. Stateful connections + capability negotiation at handshake.
- **Three-party model**: Hosts (LLM applications that initiate connections) + Clients (connectors within the host) + Servers (services providing context and capabilities).
- **Server-side primitives (offered to clients)**: Resources (context/data), Prompts (templated workflows), Tools (functions for the LLM to execute).
- **Client-side primitives (offered to servers)**: Sampling (server-initiated agentic behaviors + recursive LLM interactions), Roots (URI/filesystem boundary inquiries), Elicitation (server-initiated requests for additional info from users).
- **Capability negotiation at handshake**: Both sides declare capabilities; either side that requests an unsupported capability gets an explicit error. NO implicit fallback.
- **Tool safety = arbitrary code execution**: Tools represent arbitrary code execution. Tool annotations from servers are UNTRUSTED unless from a trusted server. Hosts MUST obtain explicit user consent before invoking any tool.
- **LLM Sampling is gated**: Server-initiated LLM calls (sampling) require explicit user approval per request. Users control whether sampling occurs at all, the prompt, AND what results the server can see.
- **Inspired by LSP (Language Server Protocol)**: Same architectural shape — standardize how to add a feature class across an ecosystem of tools.

## Verbatim quotes worth preserving

> "The Model Context Protocol enables powerful capabilities through arbitrary data access and code execution paths. With this power comes important security and trust considerations that all implementors must carefully address."

> "Tools represent arbitrary code execution and must be treated with appropriate caution. In particular, descriptions of tool behavior such as annotations should be considered untrusted, unless obtained from a trusted server."

> "The protocol intentionally limits server visibility into prompts."

## Implications for the engine catalog

The three-party Host/Client/Server model is the kit's mental model; the engine just needs to make it explicit (currently the kit treats Claude Code as both Host and Client implicitly). The "tool annotations are untrusted" rule is a critical security finding — the engine MUST scan tool annotations for prompt injection per `prompt-injection-policy.md` Rule 1. The Sampling primitive (server-initiated LLM calls) is a powerful pattern the kit doesn't currently use; F-NNN candidate to expose Sampling as a first-class engine surface for skills that need recursive LLM behavior. The capability-negotiation pattern at handshake is cleaner than the kit's current "try-and-handle-failure" pattern; engine should adopt explicit capability declaration.

## NEW F-NNN candidates

- F-029 host-client-server-model-explicit — Engine documents and enforces the three-party model; skills declare which role they assume — confidence: H
- F-030 untrusted-tool-annotations — Engine scans MCP tool annotations through the prompt-injection scanner (treating them as untrusted external content per the spec) — confidence: H
- F-031 mcp-sampling-primitive — Engine exposes Sampling (server-initiated LLM calls) as a first-class capability; gated by per-request user approval per the spec — confidence: M
- F-032 mcp-elicitation-primitive — Engine surfaces Elicitation (server-initiated user-info request) as a first-class primitive; integrates with existing AskUserQuestion — confidence: M
- F-033 explicit-capability-negotiation — Engine declares capability requirements at handshake and fails fast on missing capabilities (vs current try-and-handle pattern) — confidence: H

## Confidence

HIGH — Authoritative MCP spec. Every primitive named here is normative; the engine should treat them as the canonical contract surface.
