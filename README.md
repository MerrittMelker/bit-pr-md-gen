# Bitbucket PR to Markdown Exporter

This tool exports a Bitbucket pull request (PR) to a well-structured Markdown file, including metadata, description, reviewers, comments, and the diff.

## Setup

1. **Configure Credentials**
   - Create a `config.json` file in the same folder as the scripts:
     ```json
     {
       "workspace": "your-workspace",
       "baseUrl": "https://api.bitbucket.org/2.0/repositories",
       "username": "your-username",
       "appPassword": "your-app-password"
     }
     ```

2. **Requirements**
   - Windows with PowerShell 5+ (default on Windows 10/11)
   - Internet access to Bitbucket API

## Usage

### Command Line

Open a terminal in this folder and run:

```powershell
powershell -ExecutionPolicy Bypass -File .\Export-BitbucketPR.ps1 -RepoSlug <repo> -PRNumber <number>
```

Example:
```powershell
powershell -ExecutionPolicy Bypass -File .\Export-BitbucketPR.ps1 -RepoSlug tnc-main -PRNumber 12345
```

### Double-Click or Start Menu Shortcut

- Double-click `export-pr.bat` and follow the prompts.
- To add to Start Menu:
  1. Right-click `export-pr.bat` → Create shortcut.
  2. Move the shortcut to `%APPDATA%\Microsoft\Windows\Start Menu\Programs`.
  3. Optionally, change the icon and name.

## Output

A Markdown file named `PR-<RepoSlug>-<PRNumber>.md` will be created in the same folder.

## Customization

- To add JIRA integration or other features, edit `Export-BitbucketPR.ps1`.

---

**Security Note:**
- Store your app password securely. Do not commit `config.json` with real credentials to version control.

