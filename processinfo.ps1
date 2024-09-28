$layout = New-SpectreLayout -Name "root" -Rows @(
    (
        New-SpectreLayout -Name "header" -MinimumSize 5 -Ratio 1 -Data ("empty")
    ),
    (
        New-SpectreLayout -Name "content" -Ratio 10 -Columns @(
            (
                New-SpectreLayout -Name "processlist" -Ratio 2 -Data "empty"
            ),
            (
                New-SpectreLayout -Name "processInfo" -Ratio 4 -Data "empty"
            )
        )
    )
)
function Get-TitlePanel {
    $count = Get-Process 
    return "Process Info [purple]- $($count.Length) Running Processes[/] [gray]- $(Get-Date)[/]" | Format-SpectreAligned -HorizontalAlignment Center -VerticalAlignment Middle | Format-SpectrePanel -Expand
}

function Get-ProcessListPanel {
    param (
        $Processes,
        $SelectedProcess
    )
    $index = $Processes.IndexOf($selectedProcess) - 12
    if ($index -lt 0){$index=0}
    $ProcessList = $Processes[$index..$Processes.Length] | ForEach-Object {
        $name = "$($_.Name)"
        if (($_.Name -eq $SelectedProcess.Name) -and ($_.Id -eq $SelectedProcess.Id)) {
            $name = "[Turquoise2]$($name)[/]"
        }
        return $name
    } | Out-String
    return Format-SpectrePanel -Header "[white]Process List[/]" -Data $ProcessList.Trim() -Expand
}

function Get-ProcessInfoPanel {
    param (
        $SelectedProcess
    )
    $item = $SelectedProcess
    $result =''
        try {
            $content = Get-Process -Name $item.Name | Where-Object {$_.Id -eq $item.Id}|
            Select-Object Description,Name, Id, CPU, Handles, @{Name="WorkingSet64 (MB)";Expression={[math]::round($_.WorkingSet64 / 1MB, 2)}},
            Threads, StartTime, Responding, PrivateMemorySize, MainWindowTitle, Path, @{Name="PeakWorkingSet64 (MB)";Expression={[math]::round($_.PeakWorkingSet64 / 1MB, 2)}},TotalProcessorTime |
            Out-String
            $result = "[Turquoise2]$($content | Get-SpectreEscapedText)[/]"
        } catch {
            $result = "[red]Error reading Process content: $($_.Exception.Message | Get-SpectreEscapedText)[/]"
        }
    
    return $result | Format-SpectrePanel -Header "[white]Process Info[/]" -Expand
}

function Get-LastKeyPressed {
    $lastKeyPressed = $null
    while ([Console]::KeyAvailable) {
        $lastKeyPressed = [Console]::ReadKey($true)
    }
    return $lastKeyPressed
}

Invoke-SpectreLive -Data $layout -ScriptBlock {
    param (
        [Spectre.Console.LiveDisplayContext] $Context
    )

    # State
    $ProcessList = Get-Process
    $selectedProcess = $ProcessList[0]
    # Input
    while ($true) {
        $lastKeyPressed = Get-LastKeyPressed
        if ($lastKeyPressed -ne $null) {
            if (($lastKeyPressed.Key -eq "DownArrow") -or ($lastKeyPressed.Key -eq "j")) {
                $selectedProcess = $ProcessList[($ProcessList.IndexOf($selectedProcess) + 1) % $ProcessList.Count]
            } elseif (($lastKeyPressed.Key -eq "UpArrow") -or ($lastKeyPressed.Key -eq "k")) {
                $selectedProcess = $ProcessList[($ProcessList.IndexOf($selectedProcess) - 1 + $ProcessList.Count) % $ProcessList.Count]
            } elseif (($lastKeyPressed.Key -eq "Escape") -or ($lastKeyPressed.Key -eq "q")){
                return
            }
        }
        # Update
        $titlePanel = Get-TitlePanel
        $ProcessListPanel = Get-ProcessListPanel -Processes $ProcessList -SelectedProcess $selectedProcess
        $processInfoPanel = Get-ProcessInfoPanel -SelectedProcess $selectedProcess

        $layout["header"].Update($titlePanel) | Out-Null
        $layout["processlist"].Update($ProcessListPanel) | Out-Null
        $layout["processInfo"].Update($processInfoPanel) | Out-Null


        $Context.Refresh()
        Start-Sleep -Milliseconds 200
    }
}