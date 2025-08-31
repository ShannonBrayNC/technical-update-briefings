# Set the folder path containing your Python files
$folderPath = "C:\technical_update_briefings\tools\ppt_working\"

# Set the output combined file path
$outputFile = "C:\technical_update_briefings\tools\ppt_working\needed_parsers.md"

# Get all .py files recursively (remove -Recurse if only current folder)
$pythonFiles = Get-ChildItem -Path $folderPath -Filter *.py -Recurse

# Initialize or clear the output file
if (Test-Path -Path $outputFile) {
    Clear-Content -Path $outputFile
} else {
    New-Item -Path $outputFile -ItemType File | Out-Null
}

# Loop through each Python file
foreach ($file in $pythonFiles) {
    # Add a header with filename for clarity
    Add-Content -Path $outputFile -Value "### File: $($file.FullName) ###"
    Add-Content -Path $outputFile -Value ""  # blank line

    # Read and append file content
    Get-Content -Path $file.FullName | Add-Content -Path $outputFile

    # Add separator for readability
    Add-Content -Path $outputFile -Value "`n--- End of $($file.Name) ---`n`n"
}

Write-Output "Combined ${pythonFiles.Count} files into $outputFile"