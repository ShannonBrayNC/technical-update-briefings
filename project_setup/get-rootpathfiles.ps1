# Define the root directory
$rootPath = "../technical_update_briefings"

# Get all .patch files recursively
$patchFiles = Get-ChildItem -Path $rootPath -Recurse -Filter *.patch -File

# Create a structured object for each file
$patchInfo = $patchFiles | ForEach-Object {
    [PSCustomObject]@{
        FileName       = $_.Name
        FullPath       = $_.FullName
        RelativePath   = $_.FullName.Substring($rootPath.Length).TrimStart('\')
        LastModified   = $_.LastWriteTime
        Directory      = $_.DirectoryName
    }
}

# Output to console or pipe to JSON for AI ingestion
$patchInfo | ConvertTo-Json -Depth 3