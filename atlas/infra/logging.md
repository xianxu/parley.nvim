# Logging

- `log_file`: path to log file
- `log_sensitive`: boolean, enables sensitive data logging (default off)
- Levels: INFO, DEBUG, WARNING, ERROR
- Secrets never logged by default; redaction of sensitive JSON fields recommended
- `:ParleyInspectLog`: open log in buffer
- `:ParleyInspectPlugin`: display current plugin state/config
