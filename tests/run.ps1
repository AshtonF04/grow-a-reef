# Runs tests/reef.spec.luau outside Studio with the standalone Luau CLI.
# Usage: ./tests/run.ps1 [-Luau path\to\luau.exe]
# Get luau.exe from https://github.com/luau-lang/luau/releases (luau-windows.zip).

param([string]$Luau = "luau")

$root = Split-Path -Parent $PSScriptRoot
$modules = [ordered]@{
	GameConfig         = "src/shared/Config/GameConfig.luau"
	CoralDefinitions   = "src/shared/Config/CoralDefinitions.luau"
	SocketDefinitions  = "src/shared/Config/SocketDefinitions.luau"
	Types              = "src/shared/Types.luau"
	ReefRules          = "src/shared/ReefRules.luau"
	PlayerStateService = "src/server/PlayerStateService.luau"
}

$out = New-Object System.Text.StringBuilder
[void]$out.AppendLine((Get-Content (Join-Path $PSScriptRoot "shim.luau") -Raw))
foreach ($name in $modules.Keys) {
	$source = Get-Content (Join-Path $root $modules[$name]) -Raw
	$source = $source -replace '--!strict', ''
	$source = $source -replace 'require\(script\.Parent(?:\.Config)?\.(\w+)\)', '__require("$1")'
	$source = $source -replace 'require\(ReplicatedStorage\.Shared(?:\.Config)?\.(\w+)\)', '__require("$1")'
	[void]$out.AppendLine("__modules[`"$name`"] = function()")
	[void]$out.AppendLine($source)
	[void]$out.AppendLine("end")
}
[void]$out.AppendLine((Get-Content (Join-Path $PSScriptRoot "reef.spec.luau") -Raw))

$bundle = Join-Path ([System.IO.Path]::GetTempPath()) "reef_spec_bundle.luau"
[System.IO.File]::WriteAllText($bundle, $out.ToString(), (New-Object System.Text.UTF8Encoding $false))
& $Luau $bundle
exit $LASTEXITCODE
