docker compose --profile dev restart app_dev | Out-Null
$start = Get-Date

do {
  Start-Sleep -Milliseconds 200
  try {
    Invoke-WebRequest -UseBasicParsing http://localhost:8000/ready | Out-Null
    $ok = $true
  } catch {
    $ok = $false
  }
} until ($ok)

$elapsed = (New-TimeSpan -Start $start -End (Get-Date)).TotalMilliseconds
"rto_ready_ms=$([math]::Round($elapsed,1))"
