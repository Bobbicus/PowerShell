$HotfixNumber = Read-Host "Please Enter number including KB prefix: "
$HotfixResults = get-wmiobject -class win32_quickfixengineering | Where{$_.HotFixID -match $Hotfixnumber};
$BBTable = @(); $HotfixResults | Select-Object CSname, NAme, HotfixID, InstallDate, _Server  |ConvertTo-HTML `
| foreach {$_ -replace "&#160;",""} `
| foreach {$_ -replace "<table>","[table]"} `
| foreach {$_ -replace "<th>","[td][b]"} `
| foreach {$_ -replace "</th>","[/b][/td]"} `
| foreach {$_ -replace "<tr>","[tr]"} `
| foreach {$_ -replace "<td>","[td]"} `
| foreach {$_ -replace "</td>","[/td]"} `
| foreach {$_ -replace "</tr>","[/tr]"} `
| foreach {$_ -replace "</table>","[/table]"} `
| foreach {if ($_ -like "[[]t*")  {$BBTable += $_} elseif ($_ -like "[[]/t*") {$BBTable += $_} };
Write-Host -ForegroundColor Green "Content to be converted to BBcode:"; $HotfixResults;
Try {$BBTable | clip} Catch {Write-Host -ForegroundColor Red "Error using Clip.exe, check path."; Break};
Write-Host -ForegroundColor Green "BBcode Table sent to clipboard, paste into core ticket. Preview ticket before submitting.";