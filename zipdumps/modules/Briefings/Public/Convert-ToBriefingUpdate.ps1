#requires -Version 7.0
function Convert-ToBriefingUpdate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $InputObject
    )
    if (-not $InputObject) { throw 'InputObject is required.' }

    return $InputObject
}
