# ====================================================================
#  API Explorer Script
# ====================================================================
# Just a quick script I made that enumerates through a rest API call and gets information. This is helpful when trying to find the appropriate values for bicep templates.
# Also shows you how to interact with Azure REST APIs.


$sub = "<azure_subscription>"
$rg = "<azure_rg>"
$wk = "<loganalyticsworkspace>"
$apiUrl = "Specific REST API Call"

$token = az account get-access-token --resource https://management.azure.com/ | ConvertFrom-Json
$headers = @{
    'Authorization' = "Bearer $($token.accessToken)"
    'Content-Type' = 'application/json'
    }

Write-Host "Querying Azure for all the details..." -ForegroundColor Yellow

try {
    $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get
    Write-Host "✓ Got data back!" -ForegroundColor Green
} catch {
    Write-Host "❌ API call failed!" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Red
    
    # Try to get more error details
    if ($_.Exception.Response) {
        try {
            $errorStream = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($errorStream)
            $errorBody = $reader.ReadToEnd()
            Write-Host "Error details: $errorBody" -ForegroundColor Red
        } catch {
            Write-Host "Couldn't read error details" -ForegroundColor Red
        }
    }
    
    Write-Host "🚨 STOP HERE - Fix the error before continuing!" -ForegroundColor Red
}

Write-Host "Quick And Dirty:" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green
$response.value | Select-Object name, properties | Format-List

Write-Host "Expanded Properties:" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green
$response.value | Select-Object name -ExpandProperty properties


Write-Host "`API STRUCTURE MAP:" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green

function Show-ObjectStructure {
    param(
        $Object,
        $Path = "",
        $Level = 0,
        $MaxLevel = 4
    )
    
    if ($Level -gt $MaxLevel) {
        return
    }
    
    $indent = "  " * $Level
    $levelIcon = switch ($Level) {
        0 { "🔹" }
        1 { "  📁" }
        2 { "    📋" }
        3 { "      🔸" }
        default { "        •" }
    }
    
    if ($Object -is [Array]) {
        Write-Host "$indent$levelIcon $Path [Array with $($Object.Count) items]" -ForegroundColor Yellow
        if ($Object.Count -gt 0) {
            Write-Host "$indent    Sample item structure:" -ForegroundColor Gray
            Show-ObjectStructure -Object $Object[0] -Path "$Path[0]" -Level ($Level + 1) -MaxLevel $MaxLevel
        }
    }
    elseif ($Object -is [PSCustomObject] -or $Object -is [hashtable]) {
        if ($Path) {
            Write-Host "$indent$levelIcon $Path [Object]" -ForegroundColor Cyan
        }
        
        $properties = if ($Object -is [PSCustomObject]) { 
            $Object.PSObject.Properties 
        } else { 
            $Object.GetEnumerator() | ForEach-Object { 
                [PSCustomObject]@{Name = $_.Key; Value = $_.Value} 
            }
        }
        
        foreach ($prop in $properties) {
            $currentPath = if ($Path) { "$Path.$($prop.Name)" } else { $prop.Name }
            $value = $prop.Value
            
            if ($value -eq $null) {
                Write-Host "$indent  $levelIcon $($prop.Name): null" -ForegroundColor DarkGray
            }
            elseif ($value -is [Array]) {
                Write-Host "$indent  $levelIcon $($prop.Name): [Array with $($value.Count) items]" -ForegroundColor Yellow
                if ($value.Count -gt 0 -and $Level -lt $MaxLevel) {
                    Show-ObjectStructure -Object $value[0] -Path "$currentPath[0]" -Level ($Level + 2) -MaxLevel $MaxLevel
                }
            }
            elseif ($value -is [PSCustomObject] -or $value -is [hashtable]) {
                Write-Host "$indent  $levelIcon $($prop.Name): [Object]" -ForegroundColor Cyan
                if ($Level -lt $MaxLevel) {
                    Show-ObjectStructure -Object $value -Path $currentPath -Level ($Level + 2) -MaxLevel $MaxLevel
                }
            }
            else {
                $displayValue = if ($value -is [string] -and $value.Length -gt 40) { 
                    $value.Substring(0, 40) + "..." 
                } else { 
                    $value 
                }
                $valueType = $value.GetType().Name
                Write-Host "$indent  $levelIcon $($prop.Name): $displayValue [$valueType]" -ForegroundColor Green
            }
        }
    }
    else {
        $valueType = $Object.GetType().Name
        Write-Host "$indent$levelIcon ${Path}: $Object [$valueType]" -ForegroundColor Green
    }
}

# Show the complete structure
Show-ObjectStructure -Object $response -Path "response" -Level 0 -MaxLevel 4
