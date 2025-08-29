cd ..\technical_update_briefings

Get-ChildItem -Recurse -Depth 2 -File |
>> Where-Object { $_.FullName -notmatch '\\node_modules\\|\\\.venv\\' }