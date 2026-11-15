<#
.SYNOPSIS
    Quick network health report for a Windows PC.
.DESCRIPTION
    Shows adapters, IP addresses, DNS servers and the default gateway,
    then tests connectivity to the gateway, DNS and the internet.
    Read-only: it changes nothing on the computer.
.EXAMPLE
    .\Get-NetworkReport.ps1
#>

Write-Host "=== Network Report: $env:COMPUTERNAME ===" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date -Format yyyy-MM-dd HH:mm)"
Write-Host ""

$adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
foreach ($adapter in $adapters) {
    $ip = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1
    $dns = (Get-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).ServerAddresses -join ", "
    $route = Get-NetRoute -InterfaceIndex $adapter.ifIndex -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue | Select-Object -First 1

    Write-Host "Adapter: $($adapter.Name) ($($adapter.InterfaceDescription))"
    Write-Host "  IP address:  $($ip.IPAddress)"
    Write-Host "  DNS servers: $dns"
    Write-Host "  Gateway:     $($route.NextHop)"
    Write-Host ""
}

$gateway = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue | Select-Object -First 1).NextHop
$tests = @(
    @{ Name = "Gateway"; Target = $gateway }
    @{ Name = "DNS (8.8.8.8)"; Target = "8.8.8.8" }
    @{ Name = "Internet (microsoft.com)"; Target = "www.microsoft.com" }
)
foreach ($test in $tests) {
    if (-not $test.Target) { Write-Host "$($test.Name): skipped (no target found)"; continue }
    $ok = Test-Connection -ComputerName $test.Target -Count 2 -Quiet -ErrorAction SilentlyContinue
    $status = if ($ok) { "OK" } else { "FAILED" }
    Write-Host "$($test.Name) ($($test.Target)): $status"
}
