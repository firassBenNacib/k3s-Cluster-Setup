function Get-TemplateContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [hashtable]$Tokens,
        [switch]$NormalizeLf
    )

    if (-not $script:ModuleRoot) {
        throw "Module root is not set."
    }

    $templatesRoot = Join-Path $script:ModuleRoot "templates"
    $path = Join-Path $templatesRoot $Name
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Template not found: $Name"
    }

    $text = Get-Content -LiteralPath $path -Raw
    if ($Tokens) {
        foreach ($key in $Tokens.Keys) {
            $token = "{{{0}}}" -f $key
            $value = [string]$Tokens[$key]
            $text = $text.Replace($token, $value)
        }
    }

    if ($NormalizeLf) {
        $text = $text -replace "`r`n", "`n"
    }

    return $text
}
