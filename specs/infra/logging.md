# Spec: Logging System

## Overview
Parley's logger provides debug, information, and error tracking.

## Configuration
- `log_file`: Path to the plugin's log file.
- `log_sensitive`: Boolean to toggle sensitive data logging (e.g., API keys).

## Log Levels
- **INFO**: Regular plugin operations.
- **DEBUG**: Verbose trace for troubleshooting.
- **WARNING**: Potential issues that don't stop the plugin.
- **ERROR**: Critical failures.

## Sensitive Data Protection
- Secrets MUST NOT be logged by default.
- Redaction of sensitive fields in JSON payloads is RECOMMENDED.

## Inspections
- `:ParleyInspectLog`: Opens the log file in a Neovim buffer.
- `:ParleyInspectPlugin`: Displays current plugin state and config for troubleshooting.
