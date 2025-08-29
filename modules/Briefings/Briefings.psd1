#requires -Version 7.0
@{
    RootModule        = 'Briefings.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'c3d7f3b2-b5a8-4f2a-8f06-5a0b2b2aa001'
    Author            = 'Shannon Bray & Contributors'
    CompanyName       = 'Technical Update Briefings'
    CompatiblePSEditions = @('Core')
    PowerShellVersion = '7.0'
    FunctionsToExport = @('Get-BriefingGraphMessages','Get-M365Roadmap','Convert-ToBriefingUpdate')
    PrivateData       = @{ PSData = @{ Tags = @('briefings','m365','graph') } }
}
