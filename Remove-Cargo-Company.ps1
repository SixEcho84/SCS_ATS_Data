$cargoList          = "D:\Modding\ATS\Scripte\Cargo-Mod\Scripte\data"
$companyListByGroup = "D:\Modding\ATS\Scripte\Cargo-Mod\Scripte\data\Company_Cargo_Group.csv"
$companyListByCargo = "D:\Modding\ATS\Scripte\Cargo-Mod\Scripte\data\Company_In_Out_Custom.csv"
$cargoCustomList    = "D:\Modding\ATS\Scripte\Cargo-Mod\Scripte\data\Cargo_In_Out_Custom.csv"
$fullCompnayList    = "D:\Modding\ATS\Scripte\Scripts\data\companys_non_sortet_last.json"
$cargoDataFile      = "D:\Modding\ATS\Scripte\Scripts\data\company_cargo_last.json"
$outputBasePath     = "D:\Modding\ATS\Scripte\Cargo-Mod\Cargo IN-OUT\"


$selector = "SCS"

$outputPath = Join-Path $outputBasePath $selector

#Einlesen Cargo Liste, erstellt aus get-cargo-data.ps1
$jsonName   = "_cargo.json"
$importJson = Join-Path $cargoList ($selector + $jsonName)
$dataList   = Get-Content $importJson -Raw | ConvertFrom-Json

$fullCompnayList = Get-Content $fullCompnayList -Raw | ConvertFrom-Json

#Einlesen der Company Liste mit Cargo Gruppen
$removeCargoByGroup = Import-Csv $companyListByGroup
$acceptCargoByName  = Import-Csv $companyListByCargo
$customCargoList = Import-Csv $cargoCustomList


#Einlesen der der Companys welche Güter angenommen werden, erstellt aus generate_companys_cargo_json.ps1
$cargoData      = Get-Content $cargoDataFile -Raw | ConvertFrom-Json
$cargoDataOrgin = $cargoData

clear
# -----------------------------
# Cargo-Company Mapping
# -----------------------------
$cargoCompany = foreach ($item in $dataList) {

    # Extrahiere Cargo Name und Group
    $cargo      = ($item.cargo_data -split '\.')[1]
    $cargoDlc   = $item.dlc
    $cargoGroup = $item.group

    # Listen für IN/OUT Companies
    $inCompany  = [System.Collections.Generic.List[object]]::new()
    $outCompany = [System.Collections.Generic.List[object]]::new()

    # Firmen, die diese CargoGroup NICHT akzeptieren
    $companyNotAccept = $removeCargoByGroup | Where-Object { $_.$cargoGroup -eq 0 }

    # Firmen, die diese CargoGroup akzeptieren
	# Um Like matches zu Excludieren
    $companyAccept = @(
        ($removeCargoByGroup | Where-Object { $_.$cargoGroup -eq 1 }).company) | 
        Where-Object { $_ } | 
            ForEach-Object { $_.Trim().ToLower()
        }

    foreach ($company in $companyNotAccept) {

        # Bereinige Firmenname für robustes Matching
        $companyName = $company.company.Trim().ToLower()

        # Filtere CargoData nach Company + Cargo
        $matches = $cargoData | Where-Object {
            $dataCompany = $_.company.Trim().ToLower()
            
            # Firma darf nicht in der Accept-Liste sein
            $dataCompany -like "*$companyName*" -and
            $dataCompany -notin $companyAccept
        }

        # Iteriere über alle Matches und prüfe IN/OUT Cargos
        foreach ($m in $matches) {

            # Prüfe IN-OUT-Cargo
            #Gibt es für die Firma einen extra eintrag in der $acceptCargoByName Liste?

            #Manipuliere Remove Liste
            $acceptCompanyCargo = @()
            $acceptCompanyCargo = (($acceptCargoByName[0].psobject.properties.name) | % { ($_ -Split":",2)[1] } | group).Name

            $companyAllCargo = $cargoDataOrgin | Where-Object company -eq $m.company 

            #if($m.company -eq "hms_con_svc"){pause}

            $acceptCompanyCargo | % {
                $part = $_

                if($m.company -eq "$part"){
                    $inListCompany = $acceptCargoByName | ForEach-Object { $_."in:$part" }
                    $m.in = $m.in | Where-Object { $_.name -notin $inListCompany }
                
                    $outListCompany = $acceptCargoByName | ForEach-Object { $_."out:$part" }
                    $m.out = $m.out | Where-Object { $_.name -notin $outListCompany }
                }elseif($m.company -like "*$part*"){
                    $inListCompany = $acceptCargoByName | ForEach-Object { $_."in:$part" }
                    $m.in = $m.in | Where-Object { $_.name -notin $inListCompany }
                
                    $outListCompany = $acceptCargoByName | ForEach-Object { $_."out:$part" }
                    $m.out = $m.out | Where-Object { $_.name -notin $outListCompany }
                }
            }

            # Prüfe IN-Cargo
            if ($m.in -and ($m.in | Where-Object { $_.name -eq $cargo })) {
                $inCompany.Add($m)
            }

            # Prüfe OUT-Cargo
            if ($m.out -and ($m.out | Where-Object { $_.name -eq $cargo })) {
                $outCompany.Add($m)
            }
        }
    }

    # Wenn mindestens ein Match existiert, erstelle PSCustomObject
    if ($inCompany.Count -or $outCompany.Count) {
        [pscustomobject]@{
            cargo         = $cargo
            dlc           = $cargoDlc
            inCompany     = $inCompany  | Select-Object -Property company,dlc
            outCompany    = $outCompany | Select-Object -Property company,dlc
        }
    }
}

#$cargoCompany | ? cargo -eq "cattle" | % { $_.InCompany }

function Process-CargoDirection {
    param(
        $Companies,
        [string]$Direction, # in | out
        [string]$CargoDefName,
        [string]$CargoDlc,
        [string]$CargoName
    )
    foreach ($entry in $Companies) {
        $company    = $entry.company
        $dlc        = $entry.dlc


        if($CargoDlc -notin "custom","base"){
            $targetPath = Join-Path (Join-Path $OutputPath $CargoDlc) "def/company"
        }else{
            if($CargoDlc -eq "custom"){ $dlc = "base" }
            $targetPath = Join-Path (Join-Path $OutputPath $dlc) "def/company"
        }

        $targetPath = Join-Path $targetPath $company
        $targetPath = Join-Path $targetPath $Direction
        foreach ($cfg in $entry.$Direction) {
             
            if ($cfg.name -ne $CargoDefName) { continue }

            if (!(Test-Path $targetPath)) {
                New-Item -Path $targetPath -ItemType Directory -Force | Out-Null
            }

            $file = Join-Path $targetPath $cfg.configfile
            New-CargoSiiFile -Path $file -CargoDefName $CargoDefName -CargoName $CargoName
        }
    }
}

function Get-MissingCompanyCargo {
    param (
        [Parameter(Mandatory)]
        [array]$CargoData,

        [Parameter(Mandatory)]
        [array]$AcceptCargoByName,

        [Parameter(Mandatory)]
        [ValidateSet('in','out')]
        [string]$Direction
    )

    # verfügbare Firmen-Parts ermitteln (in:* / out:*)
    $availableParts = (
        $AcceptCargoByName[0].PSObject.Properties.Name |
        Where-Object { $_ -like "${Direction}:*" } |
        ForEach-Object { $_ -replace "^${Direction}:", "" } |
        Group-Object
    ).Name

    foreach ($entry in $CargoData) {

        $company           = $entry.company
        $companyCargoList  = $entry.$Direction.name
        $missingCargo      = @()
        $partToUse         = $null

        # exakter Firmenmatch
        if ($company -in $availableParts) {
            $partToUse = $company
        }
        else {
            # Teilmatch (Substring)
            $partToUse = $availableParts | Where-Object { $company -like "*$_*" } | Select-Object -First 1
        }

        if (-not $partToUse) {
            continue
        }

        $missingCargo = foreach ($cfg in $AcceptCargoByName) {
            $cargo = $cfg."${Direction}:$partToUse"
            if ($cargo -and $cargo -notin $companyCargoList) {
                $cargo
            }
        }
        

        foreach ($cargoName in $missingCargo) {
            $cargoDlcName   = ($dataList | ? { $($_.cargo_data).Split(".")[1] -eq $cargoName }).dlc
            $companyDlcName = ($fullCompnayList | ? { $_.companys -eq $company }).dlc

            [pscustomobject]@{
                company    = $company
                name       = $cargoName
                configfile = "${cargoName}_se_cim.sii"
                dlcCargo   = $cargoDlcName
                dlcCompany = $companyDlcName
            }
        }
    }
}

function Write-NewCargoFiles {
    param (
        [Parameter(Mandatory)]
        [array]$CargoList,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [Parameter(Mandatory)]
        [ValidateSet('in','out')]
        [string]$Direction
    )

    foreach ($cargo in $CargoList) {
        
        # DLC-Ordner bestimmen
        if ($cargo.dlcCargo -ne 'base') {
            $dlcFolder = $cargo.dlcCargo
        }
        else {
            $dlcFolder = $cargo.dlcCompany
        }

        # Zielpfad aufbauen
        $targetPath = Join-Path $OutputPath $dlcFolder
        $targetPath = Join-Path $targetPath 'def/company'
        $targetPath = Join-Path $targetPath $cargo.company
        $targetPath = Join-Path $targetPath $Direction

        # Verzeichnis anlegen (Test-Path nicht nötig)
        New-Item -Path $targetPath -ItemType Directory -Force | Out-Null

        # Datei-Pfad
        $file = Join-Path $targetPath $cargo.configfile

        New-CargoSiiFile `
            -Path $file `
            -CargoDefName $cargo.name `
            -CargoName $cargo.name
    }
}

function New-CargoSiiFile {
    param(
        [string]$Path,
        [string]$CargoDefName,
        [string]$CargoName
    )

    $content = @"
SiiNunit
{
  cargo_def : .$CargoDefName
  {
    cargo: "cargo.$CargoName"
  }
}
"@

    Set-Content -Path $Path -Value $content -Encoding UTF8
}

##############################################################################
# Anwendung der Cargo_In_Out_Custom Liste, es werden nur einträge mit dem Prefix R: und E: genutzt
#

# ===============================
# Lookup-Tabelle für Richtung & In/Out
# ===============================
$actionLookup = @{
    # Base=B
    "B|B" = @{ In=$false; Out=$false }
    "B|I" = @{ In=$false; Out=$true }
    "B|O" = @{ In=$true;  Out=$false }
    "B|"  = @{ In=$true;  Out=$true }

    # Base=I
    "I|B" = @{ In=$false; Out=$false }
    "I|I" = @{ In=$false; Out=$false }
    "I|O" = @{ In=$true;  Out=$false }
    "I|"  = @{ In=$true;  Out=$false }

    # Base=O
    "O|B" = @{ In=$false; Out=$false }
    "O|I" = @{ In=$false; Out=$true }
    "O|O" = @{ In=$false; Out=$false }
    "O|"  = @{ In=$false; Out=$true }
}

# ===============================
# Ergebnisliste initialisieren
# ===============================
$removeCargoList = @()

# ===============================
# Durchlaufe alle Cargo-Typen
# ===============================
$removeCargoList =
$customCargoList[0].PSObject.Properties.Name | ForEach-Object {

    $cargoToRemove = $_

    # CustomCompany und ExclusionCompany extrahieren
    $customCompany    = $customCargoList.$cargoToRemove | Where-Object { $_ -like "R:*" } | ForEach-Object { $_ -replace "^R:","" }
    $exclusionCompany = $customCargoList.$cargoToRemove | Where-Object { $_ -like "E:*" } | ForEach-Object { $_ -replace "^E:","" }

    # Wenn es keine CustomCompany gibt, überspringe
    if (-not $customCompany) { return }

    foreach ($c in $customCompany) {

        # BaseCompany und BaseDirection
        $parts = $c -split ":"
        $baseCompany   = $parts[0]
        $baseDirection = $parts[1]

        # Suche die Firma in cargoData
        $matchingCompanies = $cargoData | Where-Object { $_.company -like "*$baseCompany*" }

        foreach ($singleCompany in $matchingCompanies) {

            # Exclusion für diese Firma finden
            $toExclude = $null
            foreach ($e in $exclusionCompany) {

                # Teile die Exclusion in Company und Direction
                $eParts = $e -split ":"
                $eCompany   = $eParts[0]
                $eDirection = $eParts[1]

                # Vergleiche nur die Company
                if ($singleCompany.company -like "*$eCompany*") {
                    $toExclude = $e
                    break
                }
            }
            # ExclusionDirection setzen
            $excDirection = if ($toExclude) { $eDirection } else { "" }

            # Lookup-Key bilden
            $key = "$baseDirection|$excDirection"

            # Lookup anwenden
            $action = $actionLookup[$key]

            if ($action) {
                $toInCom  = if ($action.In)  { $singleCompany } else { $null }
                $toOutCom = if ($action.Out) { $singleCompany } else { $null }

                #foreach ($cargoName in $missingCargo) {
                    
                    #$entry.dlc
                    if ($toInCom -or $toOutCom) {
                        $cargoDlcName   = ($dataList | ? { $($_.cargo_data).Split(".")[1] -eq $cargoToRemove }).dlc
                        #$companyDlcName = ($fullCompnayList | ? { $_.companys -eq $singleCompany.company }).dlc
                        [PSCustomObject]@{
                            cargo      = $cargoToRemove
                            dlc        = $cargoDlcName
                            inCompany  = $toInCom  | Select-Object -Property company,dlc
                            outCompany = $toOutCom | Select-Object -Property company,dlc
                        }
                    }
                #}
            }

        }

    }

}


$mergedRemoveList = $removeCargoList + $cargoCompany |
    Group-Object cargo |
    ForEach-Object {
       [pscustomobject]@{
            cargo = $_.Name
            dlc   = ($_.Group.dlc | Select-Object -First 1)

            inCompany  = @($_.Group.inCompany  | Select-Object -Property company,dlc)
            outCompany = @($_.Group.outCompany  | Select-Object -Property company,dlc)
       }
} | Sort-Object -Property cargo


clear
$newInCompany  = [System.Collections.Generic.List[object]]::new()
$newOutCompany = [System.Collections.Generic.List[object]]::new()

$newInCompany  = Get-MissingCompanyCargo -CargoData $cargoData -AcceptCargoByName $acceptCargoByName -Direction in
$newOutCompany = Get-MissingCompanyCargo -CargoData $cargoData -AcceptCargoByName $acceptCargoByName -Direction out

$targetPath  = $outputPath
Write-NewCargoFiles -CargoList $newOutCompany -OutputPath $targetPath -Direction out
Write-NewCargoFiles -CargoList $newInCompany  -OutputPath $targetPath -Direction in

foreach ($cargo in $mergedRemoveList) {
    Process-CargoDirection -Companies $cargo.outCompany -Direction "out" -CargoDefName $cargo.cargo  -CargoDlc $cargo.dlc -CargoName "disabled"
    Process-CargoDirection -Companies $cargo.inCompany  -Direction "in"  -CargoDefName $cargo.cargo  -CargoDlc $cargo.dlc -CargoName "disabled"
}

$mergedRemoveList | ForEach-Object {
    Write-Host
    Write-Host "==================================================" -ForegroundColor DarkGray
    Write-Host $_.cargo -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor DarkGray
    Write-Host
    Write-Host "Removed In:"
    Write-Host
    $_.incompany.company | ForEach-Object {
        $company     = $_
        $companyName = ($fullCompnayList | Where-Object { $_.companys -eq $company }).name
        Write-Host "   - $company ($companyName)"
    }
    Write-Host
    Write-Host
    Write-Host "Removed out:"
    Write-Host
    $_.outcompany.company | ForEach-Object {
        $company     = $_
        $companyName = ($fullCompnayList | Where-Object { $_.companys -eq $company }).name
        Write-Host "   - $company ($companyName)"
    }
    Write-Host
    Write-Host
}


$mergedRemoveList
$mergedRemoveList.cargo
$cargoData | % {
    $company  = $_.company
    
    $mergedRemoveList | % {
        $cargo = $_.cargo
        $removeIn = @()
        $removeIn = $_.incompany.company -eq $company
        #clear
        
        
        if($removeIn){
        Write-Host $cargo
        $cargoData | ? { $_.company -eq $company -and $_.in.name -eq  $cargo } | % { $_.in }
        #Write-Host $cargo
        pause
        #$removeIn.cargo
        }

    }

    #$_.in | ? { $_.name -in $mergedRemoveList.cargo }




}