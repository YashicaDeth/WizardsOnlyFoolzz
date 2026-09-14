# The lane runner, versioned

These are copies of what actually runs from `C:\Users\Greg\lane-runner\`.
They live here so a disk failure does not take the automation with it.

`accounts.tsv` here has its account ids redacted -- the live file holds the
real ids, which are local Orca account folders and belong on one machine
only. To rebuild it, list `%APPDATA%\orca\codex-accounts\` and
`%APPDATA%\orca\claude-accounts\` and pair each id with a label.

Everything else is byte-identical to the live copy. `setup/ORCA_AUTOMATION.md`
explains what each one does and when it runs.

## Rebuilding the schedule from scratch

    powershell -Command "Get-ScheduledTask -TaskName 'ATG-*' | Unregister-ScheduledTask -Confirm:$false"

then re-register the four tasks: dispatch every 20 minutes, integrate hourly,
rescue every 2 hours, report every 30 minutes. Each needs a one-line `.cmd`
wrapper calling `bash.exe` with the script path, because Task Scheduler
cannot run a `.sh` directly.
