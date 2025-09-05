param (
    [Parameter(Mandatory = $true)]
    [string]$RepoSlug,

    [Parameter(Mandatory = $true)]
    [int]$PRNumber
)

# Require config.json
$configPath = Join-Path $PSScriptRoot 'config.json'
if (-not (Test-Path $configPath)) {
    Write-Error "Configuration file 'config.json' not found in script directory. Please create it (see config.json.example)."
    exit 1
}
$config = Get-Content $configPath | ConvertFrom-Json
$workspace   = $config.workspace
$baseUrl     = $config.baseUrl
$username    = $config.username
$appPassword = $config.appPassword

# Output file
$outFile = "PR-$RepoSlug-$PRNumber.md"

Write-Host "Fetching PR #$PRNumber from $RepoSlug..."

# Build credentials
$secPass   = ConvertTo-SecureString $appPassword -AsPlainText -Force
$cred      = New-Object PSCredential ($username, $secPass)

# --- Fetch PR metadata ---
$prUrl      = "$baseUrl/$workspace/$RepoSlug/pullrequests/$PRNumber"
$prResponse = Invoke-RestMethod -Uri $prUrl -Authentication Basic -Credential $cred

# --- Fetch PR diff ---
$diffUrl = "$prUrl/diff"
$diffTempFile = "$outFile.diff"
Invoke-RestMethod -Uri $diffUrl -Authentication Basic -Credential $cred -Method Get -OutFile $diffTempFile
$diffContent = Get-Content $diffTempFile -Raw
Remove-Item $diffTempFile

# --- Fetch comments (paginated) ---
$commentsUrl = "$prUrl/comments"
$comments    = @()
$nextUrl     = $commentsUrl
while ($nextUrl) {
    $resp     = Invoke-RestMethod -Uri $nextUrl -Authentication Basic -Credential $cred
    $comments += $resp.values
    $nextUrl  = $resp.next
}

# --- Format comments ---
$commentSection = if ($comments.Count -gt 0) {
    ($comments | Sort-Object created_on | ForEach-Object {
        $author  = $_.user.display_name
        $created = $_.created_on
        $content = $_.content.raw
        if ($_.inline) {
            $file   = $_.inline.path
            $line   = $_.inline.toString
            "### [$author @ $created] ($file:$line)`n$content`n"
        } else {
            "### [$author @ $created]`n$content`n"
        }
    }) -join "`n"
} else {
    "_No comments found._"
}

# --- Write combined output ---
$md = @"
# Pull Request: $($prResponse.title)

**Repository:** $RepoSlug  
**PR ID:** $PRNumber  
**Author:** $($prResponse.author.display_name)  
**State:** $($prResponse.state)  
**Created On:** $($prResponse.created_on)

---

## Description
$($prResponse.description)

---

## Reviewers
$($prResponse.reviewers.display_name -join ", ")

---

## Comments
$commentSection

---

## Diff
```diff
$diffContent
```
"@

$md | Out-File $outFile -Encoding UTF8

Write-Host "Export complete: $outFile"
