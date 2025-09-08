param (
    [string]$RepoSlug,
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
$apiToken    = $config.apiToken           # <-- NEW: API token replaces appPassword

# Load from config if not provided
if (-not $RepoSlug) { $RepoSlug = $config.repoSlug }
if (-not $PRNumber) { $PRNumber = $config.prNumber }

if (-not $RepoSlug -or -not $PRNumber) {
    Write-Error "Repository slug and PR number must be provided either as parameters or in config.json."
    exit 1
}

# --- Build headers (manual Basic Auth for PS 5.1 compatibility) ---
$pair   = $username + ":" + $apiToken
$bytes  = [System.Text.Encoding]::ASCII.GetBytes($pair)
$base64 = [Convert]::ToBase64String($bytes)
$headersJson = @{
    "Accept"        = "application/json"
    "Authorization" = "Basic $base64"
}
$headersText = @{
# For endpoints that return text (diff), we still send auth
    "Authorization" = "Basic $base64"
}

# --- Validate credentials ---
$testUrl = "https://api.bitbucket.org/2.0/user"
try {
    $testResponse = Invoke-RestMethod -Method GET -Uri $testUrl -Headers $headersJson -ErrorAction Stop
    Write-Host "Authenticated as $($testResponse.display_name)"
} catch {
    Write-Error "Bitbucket authentication failed. Check username/app password. $($_.Exception.Message)"
    exit 1
}

# Output file
$outFile = "PR-$RepoSlug-$PRNumber.md"
Write-Host "Fetching PR #$PRNumber from $RepoSlug..."

# --- Fetch PR metadata ---
$prUrl      = "$baseUrl/$workspace/$RepoSlug/pullrequests/$PRNumber"
$prResponse = Invoke-RestMethod -Method GET -Uri $prUrl -Headers $headersJson -ErrorAction Stop

# --- Fetch PR diff ---
$diffUrl = "$prUrl/diff"
$diffTempFile = "$outFile.diff"
Invoke-RestMethod -Method GET -Uri $diffUrl -Headers $headersText -OutFile $diffTempFile -ErrorAction Stop

$diffContent = Get-Content $diffTempFile -Raw
Remove-Item $diffTempFile

# --- Fetch comments (paginated) ---
$commentsUrl = "$prUrl/comments"
$comments    = @()
$nextUrl     = $commentsUrl
while ($nextUrl) {
    $resp     = Invoke-RestMethod -Method GET -Uri $nextUrl -Headers $headersJson -ErrorAction Stop
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
            "### [$author @ $created] (${file}:${line})`n$content`n"
            
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
