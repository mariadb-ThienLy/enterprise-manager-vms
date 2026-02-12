# Windsurf Editor Rules

## AI Agent Behavior in Windsurf

### Code Generation
- Always generate complete, runnable code
- Include all necessary imports and dependencies
- Follow the project's existing code style and patterns
- Use the DRY principle - avoid code duplication
- Reference existing files and functions when applicable

### File Operations
- Read files before editing them
- Use the edit tool for modifications, not write_to_file for existing files
- Preserve file structure and formatting
- Add comments only when explicitly requested
- Maintain consistent indentation and style

### Tool Usage
- Use code_search for exploring the codebase
- Use grep_search for finding specific patterns
- Use run_command for executing shell commands
- Use edit for modifying existing files
- Use write_to_file only for creating new files

### Communication
- Be direct and concise
- Avoid unnecessary acknowledgments
- Provide clear explanations of changes
- Show file-by-file results
- Include error messages and diagnostics in decision-making

### Verification
- Always verify changes work as expected
- Run tests and validation commands
- Check script output for errors
- Never assume code works without testing
- Document verification results

### Project Context
- Refer to AGENTS.md for project-wide instructions
- Refer to VERIFY.md for verification procedures
- Refer to README.md for project overview
- Refer to TOPOLOGIES.md for topology specifications
