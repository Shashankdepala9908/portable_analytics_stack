param(
  [string]$Url = "http://localhost:8000/health",
  [int]$Total = 50,
  [int]$Conc = 10,
  [int]$TimeoutMs = 5000
)

$lats   = @()
$errors = 0
$jobs = @()

function Start-Req {
  param($Url, $TimeoutMs)
  Start-Job -ScriptBlock {
    param($Url,$TimeoutMs)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
      $req = [System.Net.WebRequest]::Create($Url)
      $req.Timeout = $TimeoutMs
      $req.ReadWriteTimeout = $TimeoutMs
      $resp = $req.GetResponse()
      $null = (New-Object System.IO.StreamReader($resp.GetResponseStream())).ReadToEnd()
      $sw.Stop()
      [pscustomobject]@{ ok=$true; ms=$sw.Elapsed.TotalMilliseconds }
    } catch {
      $sw.Stop()
      [pscustomobject]@{ ok=$false; ms=$sw.Elapsed.TotalMilliseconds }
    }
  } -ArgumentList $Url,$TimeoutMs
}

for ($i=0; $i -lt $Total; $i++) {
  while ( (@($jobs | Where-Object { $_.State -eq 'Running' }).Count) -ge $Conc ) {
    $done = Wait-Job -Job $jobs -Any -Timeout 5
    if ($done) {
      $r = Receive-Job $done -ErrorAction SilentlyContinue
      if ($r -and $r.ok) { $lats += [double]$r.ms } else { $errors++ }
      Remove-Job $done | Out-Null
      $jobs = $jobs | Where-Object { $_.Id -ne $done.Id }
    }
  }
  $jobs += (Start-Req -Url $Url -TimeoutMs $TimeoutMs)
}

Wait-Job -Job $jobs | Out-Null
foreach ($j in $jobs) {
  $r = Receive-Job $j -ErrorAction SilentlyContinue
  if ($r -and $r.ok) { $lats += [double]$r.ms } else { $errors++ }
  Remove-Job $j | Out-Null
}

if ($lats.Count -eq 0) { Write-Host "No successful responses. Errors=$errors"; exit 1 }

$sorted = $lats | Sort-Object
function Pct([double[]]$arr, [double]$p) {
  $idx = [math]::Floor(($p * $arr.Length)) - 1
  if ($idx -lt 0) { $idx = 0 }
  if ($idx -ge $arr.Length) { $idx = $arr.Length - 1 }
  return $arr[$idx]
}

"{0} requests, {1} errors | p50_ms={2:N1} p95_ms={3:N1} max_ms={4:N1}" -f $lats.Count, $errors, (Pct $sorted 0.50), (Pct $sorted 0.95), $sorted[-1]
