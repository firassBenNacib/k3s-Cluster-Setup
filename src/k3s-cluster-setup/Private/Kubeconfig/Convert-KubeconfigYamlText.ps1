function Convert-KubeconfigYamlText {
    param([Parameter(Mandatory)][string]$Text)

    $t = $Text -replace "`r`n", "`n" -replace "`r", "`n"
    $t = $t -replace 'apiVersion:\s*v1\s*clusters:', "apiVersion: v1`nclusters:"
    $t = $t -replace 'clusters:\s*-\s*cluster:', "clusters:`n- cluster:"
    $t = $t -replace 'contexts:\s*-\s*context:', "contexts:`n- context:"
    $t = $t -replace 'users:\s*-\s*name:', "users:`n- name:"
    $t = $t.TrimEnd() + "`n"
    return ($t -replace "`n", [Environment]::NewLine)
}
