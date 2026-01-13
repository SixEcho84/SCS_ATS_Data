$outJsonPath = "D:\Modding\ATS\Scripte\Scripts\data"

$jrt = "D:\Modding\ATS\_Extract\JRT\def\company"
$scs = "D:\Modding\ATS\_Extract\SCS\base\def\company"

$basePath = $scs

$version = "1.57"
$selector = "SCS"

$companySui = (Get-ChildItem $basePath  | ? Name -Like "*.sui")





function Sui-Parser {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "Datei nicht gefunden: $Path"
    }

    $lines = Get-Content $Path | Where-Object { $_.Trim() -ne '' }

    # Header parsen
    if ($lines[0] -notmatch '^(?<root>\w+):\s+(?<type>.+)$') {
        throw "Ungültiges Dateiformat (Header)"
    }

    $rootKey = $matches.root
    $type    = $matches.type

    $properties = @{
        Type = $type
    }

    foreach ($line in $lines[1..($lines.Count - 1)]) {

        if ($line -match '^\s*(\w+):\s*(.+)$') {
            $key   = $matches[1]
            $value = $matches[2].Trim('"')

            $properties[$key] = $value
        }
    }

    return [pscustomobject]@{
        $rootKey = [pscustomobject]$properties
    }
}

if($companySui){
    $companys =
    $companySui | % {
        #$suiData = Get-Content $_.FullName



        $suiData = Sui-Parser -Path $_.FullName




        #pause

        $company = ($_.Name).Split(".")[0]
        if((($_.name).Split(".")[1]) -ne "sui" ){
            $dlcName = ($_.name).Split(".")[1]
        }else{
            $dlcName = "base"
        }
        [pscustomobject]@{
            dlc        = $dlcName
            companys   = $company
            name       = $suiData.company_permanent.name
            configfile = $_
        }
    }
}else{
    $companyList = (Get-ChildItem $basePath -Directory).name
    $companys =
    $companyList | % {
        [pscustomobject]@{
                dlc        = $selector
                companys   = $_
                configfile = ""
        }
    }
}
$jsonFileName = "companys_non_sortet_$selector" + "_$version" + ".json"
$companys | ConvertTo-Json | Out-File $outJsonPath\$jsonFileName
$companys | ConvertTo-Json | Out-File $outJsonPath\companys_non_sortet_last.json





$dlcList = (($companys).dlc | group).Name

$exportList =
$dlcList | % {
    $curDlc  = $_
    $curList = $companys | ? { $_.dlc -eq $curDlc }
    

    [pscustomobject]@{
        dlc        = $curDlc
        companys   = 
            $(foreach($i in $curList){
                [pscustomobject]@{
                    name = $i.companys
                    company = $i.name
                    configfile = $i.configfile.Name
                }
            })
    }
}
$jsonFileName = "companys_$selector" + "_$version" + ".json"

$exportList | select -Property dlc,companys | ConvertTo-Json -Depth 3 | Out-File $outJsonPath\$jsonFileName
$exportList | select -Property dlc,companys | ConvertTo-Json -Depth 3 | Out-File $outJsonPath\companys_last.json


$companyCargo =
$companys | % {
    $dlcName = $_.dlc
    $_.companys | % {

        try{
            $cargoIn = 
            foreach($i in ($basePath + "\" + $_ + "\in" | Get-ChildItem).Name){
                [pscustomobject]@{
                    name       = $i  | % { $_.Split(".")[0] } -ErrorAction Stop
                    configfile = $i
                }
            }
        }catch{
            $cargoIn = $null
        }

        try{
            $cargoOut =
            foreach($i in ($basePath + "\" + $_ + "\out" | Get-ChildItem).Name){
                [pscustomobject]@{
                    name       = $i  | % { $_.Split(".")[0] } -ErrorAction Stop
                    configfile = $i
                }
            }
        }catch{
            $cargoOut = $null
        }

        [pscustomobject]@{
           company = $_
           in      = $cargoIn
           out     = $cargoOut
           dlc     = $dlcName
        }
    } 
} | Sort -Property company

$jsonFileName = "company_cargo_$selector" + "_$version" + ".json"

$companyCargo | ConvertTo-Json -Depth 99 | Out-File $outJsonPath\$jsonFileName
$companyCargo | ConvertTo-Json -Depth 99 | Out-File $outJsonPath\company_cargo_last.json