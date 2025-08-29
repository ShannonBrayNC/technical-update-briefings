#requires -Version 7.0
Import-Module Pester
Describe 'Style' {
  It 'Targets PowerShell 7+' { $PSVersionTable.PSVersion.Major | Should -BeGreaterOrEqual 7 }
  It 'Has no here-strings' {
    $hits = Get-ChildItem -Recurse -Include *.ps1,*.psm1 |
            Select-String -Pattern '@\"|@'' -SimpleMatch
    $hits.Count | Should -Be 0
  }
  It 'Avoids Measure-Object truthiness' {
    $hits = Get-ChildItem -Recurse -Include *.ps1,*.psm1 |
            Select-String -Pattern 'Measure-Object\s*\|\s*Select-Object\s*-ExpandProperty\s*Count' -AllMatches
    $hits.Count | Should -Be 0
  }
}