#requires -Version 7.0
Import-Module "$PSScriptRoot/../modules/Briefings/Briefings.psd1" -Force

Describe 'Convert-ToBriefingUpdate' {
    It 'throws on null input (negative test)' {
        { Convert-ToBriefingUpdate -InputObject $null } | Should -Throw
    }

    It 'returns object with required fields' {
        $obj = [pscustomobject]@{ id='1'; source='m365-roadmap'; title='Test'; lastUpdatedAt=(Get-Date) }
        $out = Convert-ToBriefingUpdate -InputObject $obj
        @($out).Count | Should -Be 1
        $out.id | Should -Be '1'
        $out.source | Should -Be 'm365-roadmap'
    }
}

Describe 'Get-M365Roadmap (mocked)' {
    BeforeAll {
        $env:M365_ROADMAP_BASE = 'https://example.test/api'
        Mock Invoke-RestMethod { @{ items = @(@{ id=42; title='Feat'; lastModifiedDateTime=(Get-Date).AddDays(-1) }) } }
    }
    It 'returns at least one item' {
        $items = Get-M365Roadmap -Top 10
        @($items).Count | Should -BeGreaterThan 0
    }
}
