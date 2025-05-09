# Changelog

## [Unreleased]
### Added
- Header-based configuration overrides: allows setting configuration parameters like `max_full_exchanges` on a per-chat basis in the header section
- File reference preservation: questions that include file references (@@filename) are now preserved during summarization to maintain context
- Line numbers in file inclusions: all files included with @@ syntax now show line numbers, making code references clearer

### Changed
- Removed unused spinner module (kept empty file for compatibility)
- Removed unused `grep_directory` function from tasker module
- Removed unused `prompt_template` function from render module
- Removed unused `nested` function from deprecator module
- Simplified debug reporting in tasker module

## [1.0.0](https://github.com/xianxu/gp.nvim/compare/v1.0.0) (2025-04-25)
