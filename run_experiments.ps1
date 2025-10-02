# Holomorphic Equilibrium Propagation - Experiment Runner
# This script has two modes: "clean" and "run"

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("clean", "run")]
    [string]$Mode
)

# Experiment mapping based on README.md
$experimentMap = @{
    "fig2ac" = "dynamics.py"
    "fig2b" = "stability_map.py"
    "fig2d" = "sweep_beta.py"
    "fig3ab" = "outer_dynamics.py"
    "fig3c" = "sweep_beta.py"
    "fig4a" = "sweep_beta.py"
    "fig4b" = "sweep_beta.py"
    "fig4c" = "train.py"
    "table1" = "train.py"
    "table2" = "train.py"
}

$resultsFolder = ".\results"
$scriptsRoot = "."

function Clean-Results {
    Write-Host "=== CLEAN MODE ===" -ForegroundColor Cyan
    Write-Host "Removing all non-JSON files from $resultsFolder recursively..." -ForegroundColor Yellow
    
    if (-not (Test-Path $resultsFolder)) {
        Write-Host "Results folder not found: $resultsFolder" -ForegroundColor Red
        return
    }
    
    # Get all files that are NOT .json files
    $filesToDelete = Get-ChildItem -Path $resultsFolder -Recurse -File | Where-Object { $_.Extension -ne ".json" }
    
    $fileCount = $filesToDelete.Count
    
    if ($fileCount -eq 0) {
        Write-Host "No non-JSON files found to delete." -ForegroundColor Green
        return
    }
    
    Write-Host "Found $fileCount non-JSON files to delete." -ForegroundColor Yellow
    
    # Ask for confirmation
    $confirmation = Read-Host "Are you sure you want to delete these files? (yes/no)"
    
    if ($confirmation -eq "yes") {
        $deletedCount = 0
        foreach ($file in $filesToDelete) {
            try {
                Remove-Item -Path $file.FullName -Force
                $deletedCount++
                Write-Host "Deleted: $($file.FullName)" -ForegroundColor Gray
            }
            catch {
                Write-Host "Error deleting $($file.FullName): $_" -ForegroundColor Red
            }
        }
        Write-Host "`nSuccessfully deleted $deletedCount out of $fileCount files." -ForegroundColor Green
    }
    else {
        Write-Host "Cleanup cancelled." -ForegroundColor Yellow
    }
}

function Run-Experiments {
    Write-Host "=== RUN EXPERIMENTS MODE ===" -ForegroundColor Cyan
    Write-Host "Scanning for experiments in $resultsFolder..." -ForegroundColor Yellow
    
    if (-not (Test-Path $resultsFolder)) {
        Write-Host "Results folder not found: $resultsFolder" -ForegroundColor Red
        return
    }
    
    # Get all subdirectories in results folder (e.g., fig2ac, fig2b, etc.)
    $experimentFolders = Get-ChildItem -Path $resultsFolder -Directory
    
    $totalExperiments = 0
    $completedExperiments = 0
    $failedExperiments = 0
    
    foreach ($expFolder in $experimentFolders) {
        $expName = $expFolder.Name
        
        # Check if this experiment is in our mapping
        if (-not $experimentMap.ContainsKey($expName)) {
            Write-Host "`nSkipping unknown experiment folder: $expName" -ForegroundColor DarkGray
            continue
        }
        
        $scriptName = $experimentMap[$expName]
        $scriptPath = Join-Path $scriptsRoot $scriptName
        
        if (-not (Test-Path $scriptPath)) {
            Write-Host "`nScript not found: $scriptPath" -ForegroundColor Red
            continue
        }
        
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "Experiment Folder: $expName" -ForegroundColor Cyan
        Write-Host "Script: $scriptName" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        
        # Find all hyperparameters.json files in this experiment folder and its subdirectories
        $hyperparamFiles = Get-ChildItem -Path $expFolder.FullName -Recurse -Filter "hyperparameters.json"
        
        if ($hyperparamFiles.Count -eq 0) {
            Write-Host "No hyperparameters.json files found in $expName" -ForegroundColor Yellow
            continue
        }
        
        Write-Host "Found $($hyperparamFiles.Count) experiment(s) to run`n" -ForegroundColor Green
        
        foreach ($hyperparamFile in $hyperparamFiles) {
            $totalExperiments++
            $relativePath = $hyperparamFile.FullName.Substring((Get-Location).Path.Length + 1)
            
            Write-Host "[$totalExperiments] Running: $relativePath" -ForegroundColor White
            Write-Host "    Command: python $scriptName $($hyperparamFile.FullName)" -ForegroundColor DarkGray
            
            try {
                # Run the Python script with the hyperparameters file
                $output = python $scriptPath $hyperparamFile.FullName 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "    Status: SUCCESS" -ForegroundColor Green
                    $completedExperiments++
                }
                else {
                    Write-Host "    Status: FAILED (Exit code: $LASTEXITCODE)" -ForegroundColor Red
                    Write-Host "    Error output:" -ForegroundColor Red
                    Write-Host $output -ForegroundColor DarkRed
                    $failedExperiments++
                }
            }
            catch {
                Write-Host "    Status: ERROR - $_" -ForegroundColor Red
                $failedExperiments++
            }
            
            Write-Host ""
        }
    }
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "SUMMARY" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Total experiments: $totalExperiments" -ForegroundColor White
    Write-Host "Completed: $completedExperiments" -ForegroundColor Green
    Write-Host "Failed: $failedExperiments" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Cyan
}

# Main execution
switch ($Mode) {
    "clean" {
        Clean-Results
    }
    "run" {
        Run-Experiments
    }
}
