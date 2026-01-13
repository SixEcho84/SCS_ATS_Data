$importFiles        = "D:\Modding\ATS\Scripte\Cargo-Mod\Input"
$outputPath         = "D:\Modding\ATS\Scripte\Cargo-Mod\Output"
$exportList         = "D:\Modding\ATS\Scripte\Cargo-Mod\Scripte\data"
$customCargoListCsv = "D:\Modding\ATS\Scripte\Cargo-Mod\Scripte\data\Cargo_Custom_Settings.csv"
$cargoDataFile      = "D:\Modding\ATS\Scripte\Scripts\data\company_cargo_last.json"

$selector = "SCS"

#$importFiles = "E:\SpieleExtras\ATS\Modding\Cargo-Mod\Input_mods\*.sui"

#$costPer100Km, Kosten für 1 Tonne pro 100km (abhänging vom Diesel Durchscnittspreis in er EU) 1t=1L/100Km
#https://de.statista.com/statistik/daten/studie/295534/umfrage/durchschnittspreis-fuer-einen-liter-diesel-mit-und-ohne-steuern-in-der-eu/

$costPer100Km  = 1   #22.12.2025 USA

$basePrice     = 1.5    #Minumum Preis/Km für Low und Container
$adrFactor     = 1.1    #10% auf ADR, Wertvoll und Zerbrächlich (Bonus stackt sich nicht!)
$refFactor     = 1.05   #5% auf Kühlfracht
$ovsFactor     = 1.2    #Oversize Bonus 20%

$minimumdistance = 32 #20 miles

$minMassCalc = 10000

$maxMassLow  = 27000 # 53" 5 Achsen
$maxMassHigh = 36000 # TB 7 Achsen

$importFiles = Join-Path $importFiles $selector
$files = (Get-ChildItem $importFiles).FullName
$dataSet =
foreach ($i in $files){
    $group      = @()
    $body_types = @()
    $fileName   = Split-Path $i -leaf

    $name                      = ""
    [float]$fragility          = ""
    [int16]$adr_class          = ""
    $valuable                  = ""
    [int16]$minimum_distance   = ""
    [int16]$maximum_distance   = ""
    $overweight                = ""
    $oversize                  = ""
    [float]$prob_coef          = ""
    [float]$volume             = ""
    [float]$mass               = ""
    [float]$unit_reward_per_km = ""
    [int16]$unit_load_time     = ""

    foreach ($j in Get-Content $i){
        $j = $j.Trim()
        
        if(!($j -ne "{") -xor ($j -ne "}")){
            switch -Wildcard ($j) {
                "cargo_data:*"           {$cargo_data         = (($_).Split(":")[1]).Trim() -replace("{","") }
                "name:*"                 {$name               = (($_).Split(":")[1]).Trim() }
                "fragility*"             {$fragility          = (($_).Split(":")[1]).Trim() }
                "adr_class*"             {$adr_class          = (($_).Split(":")[1]).Trim() }
                "valuable*"              {$valuable           = (($_).Split(":")[1]).Trim() }
                "minimum_distance*"      {$minimum_distance   = (($_).Split(":")[1]).Trim() }
                "maximum_distance*"      {$maximum_distance   = (($_).Split(":")[1]).Trim() }
                "overweight*"            {$overweight         = (($_).Split(":")[1]).Trim() }
                "oversize:*"             {$oversize           = (($_).Split(":")[1]).Trim() }
                "group*"                 {$group             += (($_).Split(":")[1]).Trim() }
                "prob_coef*"             {$prob_coef          = (($_).Split(":")[1]).Trim() }
                "volume*"                {$volume             = (($_).Split(":")[1]).Trim() }
                "mass*"                  {$mass               = (($_).Split(":")[1]).Trim() }
                "unit_reward_per_km*"    {$unit_reward_per_km = (($_).Split(":")[1]).Trim() }
                "unit_load_time*"        {$unit_load_time     = (($_).Split(":")[1]).Trim() }
                "body_types*"            {$body_types        += (($_).Split(":")[1]).Trim() }
                "" {}
                default {Write-host $j $fileName }
            }
        }
    }

    if($unit_reward_per_km -xor $volume -xor $mass){


        #find dlc
        $dlcSplit = $fileName.split(".")[1]
        $dlcName  = if($dlcSplit -ne "sui"){ $dlcSplit }else{"base"}

        [pscustomobject]@{
            fileName           = $fileName
            dlc                = $dlcName
            cargo_data         = $cargo_data
            name               = $name
            fragility          = $fragility
            adr_class          = $adr_class
            valuable           = $valuable
            minimum_distance   = $minimum_distance
            maximum_distance   = $maximum_distance
            overweight         = $overweight
            oversize           = $oversize
            group              = $group
            prob_coef          = $prob_coef
            volume             = $volume
            mass               = $mass
            unit_reward_per_km = $unit_reward_per_km
            unit_load_time     = $unit_load_time
            body_types         = $body_types
            priceForKmLow      = ""
            priceForKmHigh     = ""
            massLow            = ""
            massHigh           = ""
            contType           = "undef"
            sameAsCargo        = "undef"
        }
    } else {
        Write-Host "$fileName Keine Daten zum verarbeiten" -ForegroundColor Yellow
        $j
        pause
    }


}

#####################################################################################################
# Custom New Cargo einlesen
$customCargoList = Import-Csv $customCargoListCsv

$columnsToSplit = @('group', 'body_types')

$customCargoList | ForEach-Object {
    foreach ($col in $columnsToSplit) {
        if ($_.PSObject.Properties[$col] -and $_.$col) {
            $_.$col = $_.$col -split "\|"
        }
    }
}

$newCustomData =
$customCargoList | ? { $_."Add/Chance" -eq "A" } | % {

    [pscustomobject]@{
        fileName           = $_.filename
        dlc                = "custom"
        cargo_data         = "cargo." + $_.cargo_data
        name               = $_.name
        fragility          = $_.fragility
        adr_class          = $_.adr_class
        valuable           = $_.valuable
        minimum_distance   = $_.minimum_distance
        maximum_distance   = $_.maximum_distance
        overweight         = $_.overweight
        oversize           = $_.oversize
        group              = $_.group
        prob_coef          = $_.prob_coef
        volume             = $_.volume
        mass               = $_.mass
        unit_reward_per_km = $_.unit_reward_per_km
        unit_load_time     = $_.unit_load_time
        body_types         = $_.body_types
        priceForKmLow      = ""
        priceForKmHigh     = ""
        massLow            = ""
        massHigh           = ""
        contType           = $_.contType
        sameAsCargo        = $_.sameAsCargo
    }
}

$dataSet = $dataSet + $newCustomData
$dataSet = $dataSet | Sort-Object -Property fileName

#------------------------------------------
$exportJsonFile = (Join-Path $exportList $selector) + "_cargo.json"
$dataSet | ConvertTo-Json | Out-File $exportJsonFile
pause

###############################################################################################
###############################################################################################
###############################################################################################
###############################################################################################




clear
#$dataSet | Format-Table -Property fileName,group
#$dataSet | ? { $_.group -eq $null } | Format-Table -Property fileName,group
#$dataSet | ? { $_.group } | Format-Table -Property fileName,group
#$dataSet | ? { $_.group } | Format-Table -Property fileName,group
#$dataSet | ? { $_.group -contains "refrigerated" } | Format-Table -Property fileName,body_types,group

#$dataSet | ? { $_.body_types -contains "container" } | Format-Table -Property fileName,body_types,group
#$dataSet | ? { $_.body_types -contains "container" -and $_.body_types.count -gt 1} | Format-Table -Property fileName,body_types,group


$dataSet | ? { $_.body_types -contains "dumper" } | Format-Table -Property fileName,body_types,group

#$dataSet | ? { $_.body_types -contains "refrigerated" } | Format-Table -Property fileName,body_types,group
#$dataSet | ? { $_.body_types -contains "hopper" } | Format-Table -Property fileName,body_types,group
#$dataSet | ? { $_.group -contains "bulk" } | Format-Table -Property fileName,body_types,group
#$dataSet | group -Property body_types
#$dataSet | ? { $_.group -contains "bulk" } | Format-Table -Property fileName,body_types,group
#$dataSet.cargo_data | % { $_.split(".")[1] }
#$dataSet | Sort-Object mass -Descending |  Format-Table -Property fileName,mass,volume,body_types,group

$BoxVol           = @(191,115)
$RefVol           = @(158,100)
$isoVol           = @(169,105)
$dryvanVol        = @(191,115)
$containerVol     = @(106,106) #Eigene Kalkulation wird für Container Only angewendet
$bulkfeedVol      = @(54,54) #ats
$chipvanVol       = @(102,102) #ats
#$bottomdumperVol  = @(31,16) #ats = dumper
$hopperVol        = @(109,72) #ats
$logVol           = @(77,77) #ats

$siloVol          = @(53,40) #ats drybulk

$siloAdrVol       = @(63,63)
$fuelTankVol      = @(43,35)
$chemtankVol      = @(30,37)
$gasTankVol       = @(55,55)
$foodTankVol      = @(53,35)
$dumperVol        = @(24,24)

$lowboyVol        = @(80,80)
$lowbedVol        = @(96,96)
$dropdeckVol      = @(113,113) #ats
$flatbedVol       = @(171,113)

$inloaderVol      = @(43,43)
$liveStockVol     = @(10,102)
$defaultVol       = @(100,100)

#Paltte = 3.9 Vol 
#~45 min 53" reefer
#~60 min 53" reefer

#Box 112.56 Vol ~51 min
#Reefer 99.55 ~45 min
#109 sek für 3.9
#28 sek für 1
$loadTimeContUnit   = 28

#Reefer 99.55 ~60 min
#140 sek für 3.9
#36 sek für 1
$loadTimeReeferUnit = 36

#Silo = Bulk
#Drybulk 51 ~30 min
$loadTimeSiloUnit   = 35

#Bulk
#Hopper 62   ~36 min
#bulkfeed 53 ~31 min
#Chipvan 115 ~67 min
$loadTimeBulkUnit   = 35

#Liquid
#Chemtank 37 ~34 min
#Food 37     ~34 min
#Fuel 34     ~31 min
#Gas 55      ~50 min
$loadTimeLiquidUnit = 55

#Container
#20" 40  ~7 min
#53" 106 ~18 min
$loadTimeContainer  = 10



$dataSet | % {
    $setLoadTime = 0

    $cargoNameLookup     = $_.cargo_data -replace "cargo\.", ""
    $cargoCustomSettings = $customCargoList | ? { $_.cargo_data -eq $cargoNameLookup }

    if($cargoCustomSettings.'Add/Chance' -eq "C"){

        $valuesToCopy = @(
            "group"
            "body_types"
            "volume"
            "unit_load_time"
            "mass"
            "fragility"
            "adr_class"
            "valuable"
            "minimum_distance"
            "maximum_distance"
            "overweight"
            "oversize"
            "prob_coef"
            "contType"
            "sameAsCargo"
        )

        foreach ($v in $valuesToCopy) {
            if (
                $cargoCustomSettings.PSObject.Properties[$v] -and
                -not [string]::IsNullOrEmpty($cargoCustomSettings.$v)
            ) {
                $_.$v = $cargoCustomSettings.$v
            }
        }
    }

    #Write-Host "-----------------------------"
    #$_.group
    $_.fileName
    $_.cargo_data
    $_.name

    if(!($_.group)){
        Write-Host "kein Gruppe vorhanden" -ForegroundColor Yellow
        pause
    }


    $maxVolHigh = 0
    $maxVolLow  = 0
    $sumVol     = @()
    foreach($b in $_.body_types){

        $lastVolHigh = $maxVolHigh
        $lastVolLow  = $maxVolLow

        switch -Wildcard ($b){

            "refrigerated"    {$maxVolHigh = $RefVol[0];          $maxVolLow = $RefVol[1]}
            "insulated"       {$maxVolHigh = $isoVol[0];          $maxVolLow = $isoVol[1]}
            "dryvan"          {$maxVolHigh = $dryvanVol[0];       $maxVolLow = $dryvanVol[1]}
            "curtainside"     {$maxVolHigh = $dropdeckVol[0];     $maxVolLow = $dropdeckVol[1]}
            "container"       {$maxVolHigh = $containerVol[0];    $maxVolLow = $containerVol[1] }
            "dropdeck"        {$maxVolHigh = $dropdeckVol[0];     $maxVolLow = $dropdeckVol[1] }
            "hopper"          {$maxVolHigh = $hopperVol[0];       $maxVolLow = $hopperVol[1] }
            "bulkfeed"        {$maxVolHigh = $bulkfeedVol[0];     $maxVolLow = $bulkfeedVol[1] }
            "chipvan"         {$maxVolHigh = $chipvanVol[0];      $maxVolLow = $chipvanVol[1] }
            "chemtank"        {$maxVolHigh = $chemtankVol[0];     $maxVolLow = $chemtankVol[1]}
            "gastank"         {$maxVolHigh = $gasTankVol[0];      $maxVolLow = $gasTankVol[1]}
            "fueltank"        {$maxVolHigh = $fuelTankVol[0];     $maxVolLow = $fuelTankVol[1]}
            "foodtank"        {$maxVolHigh = $foodTankVol[0];     $maxVolLow = $foodTankVol[1]}
            "dumper"          {$maxVolHigh = $dumperVol[0];       $maxVolLow = $dumperVol[1]}
            "silo"            {$maxVolHigh = $siloVol[0];         $maxVolLow = $siloVol[1]}
            "siloadr"         {$maxVolHigh = $siloAdrVol[0];      $maxVolLow = $siloAdrVol[1]}
            "flatbed_cont"    {$maxVolHigh = $containerVol[0];    $maxVolLow = $containerVol[1] }
            "flatbed"         {$maxVolHigh = $flatbedVol[0];      $maxVolLow = $flatbedVol[1]}
            "flatbed_brck"    {$maxVolHigh = $flatbedVol[0];      $maxVolLow = $flatbedVol[1]}
            "log"             {$maxVolHigh = $logVol[0];          $maxVolLow = $logVol[1]}
            "lowboy"          {$maxVolHigh = $lowboyVol[0];       $maxVolLow = $lowboyVol[1]}
            "lowbed"          {$maxVolHigh = $lowbedVol[0];       $maxVolLow = $lowbedVol[1]}
            "livestock"       {$maxVolHigh = $liveStockVol[0];    $maxVolLow = $liveStockVol[1]}
            "_seafood_01"     {$maxVolHigh = $containerVol[0];    $maxVolLow = $containerVol[1] }
            "_*"              {$maxVolHigh = $defaultVol[0];      $maxVolLow = $defaultVol[1]}
            default           {$maxVolHigh = $defaultVol[0];      $maxVolLow = $defaultVol[1];   Write-Host "Body Unbekannt $b"; pause}

        }

        $sumVol += $maxVolLow
        $maxVolHigh = [math]::max($maxVolHigh,$lastVolHigh)
        $maxVolLow  = [math]::max($maxVolLow,$lastVolLow)
    }

    $maxVolLow    = ($sumVol | Measure-Object -Average).Average
    $setBasePrice = $basePrice

    $volUnit     = $_.volume
    $massUnit    = $_.mass

    $unitsLow  = [math]::floor($maxVolLow / $volUnit)
    $unitsHigh = [math]::floor($maxVolHigh / $volUnit)

    if($unitsLow  -lt 1){ $unitsLow  = 1 }
    if($unitsHigh -lt 1){ $unitsHigh = 1 }


    $massLow  = [math]::Ceiling($unitsLow * $massUnit)
    $massHigh = [math]::Ceiling($unitsHigh * $massUnit)

    $altMassCalc = $false
    if($massLow  -lt $minMassCalc){
        $massUnit    = $minMassCalc / $unitsLow
        $altMassCalc = $true
    }


    #if($massHigh -lt $minMassCalc){ $massUnit = $minMassCalc }

    $volLow   = [math]::Round($unitsLow * $volUnit,1)
    $volHigh  = [math]::Round($unitsHigh * $volUnit,1)

    Write-Host
    Write-Host "$unitsLow Units Low"
    Write-Host "$unitsHigh Units High"

    Write-Host "$volLow Vol Low"
    Write-Host "$volHigh Vol High"

    $maxMassExceeded = $false

    if($massLow -le $maxMassLow){
        Write-Host "$massLow Kg Low"
    } else {
        $unitsLow = [math]::max([math]::floor($maxMassLow / $massUnit),1)
        $massLow  = [math]::Ceiling($unitsLow * $massUnit)
        Write-Host "$massLow Kg Low" -ForegroundColor Yellow
        Write-Host "$unitsLow Units Low" -ForegroundColor Yellow
        $maxMassExceeded = $true
    }

    if($massHigh -le $maxMassHigh){
        Write-Host "$massHigh Kg High"
    } else {
        $unitsHigh = [math]::max([math]::floor($maxMassHigh / $massUnit),1)
        $massHigh  = [math]::Ceiling($unitsHigh * $massUnit)
        Write-Host "$massHigh Kg High" -ForegroundColor Yellow
        Write-Host "$unitsHigh Units High" -ForegroundColor Yellow
        $maxMassExceeded = $true
    }


    if($_.overweight -or $_.oversize){
        $setBasePrice = $setBasePrice * $ovsFactor
        Write-Host "OW/OS Bonus" -ForegroundColor Yellow
    }

    #if($_.fragility -ge 0.7 -or $_.adr_class -gt 0 -or $_.valuable -or $_.overweight -or $_.group -contains "adr" -or $_.cargo_data -like "cargo.x_*"){
    if($_.adr_class -gt 0 -or $_.group -contains "adr"){
    Write-Host "ADR Bonus" -ForegroundColor Yellow
        $setBasePrice    = $setBasePrice * $adrFactor
        #$setBasePriceLow = ($setBasePrice / $maxVolHigh * $maxVolLow) * $adrFactor
    }elseif($_.group -contains "refrigerated"){
        Write-Host "REF Bonus" -ForegroundColor Yellow
        $setBasePrice    = $setBasePrice * $refFactor
    }else{ 
        $setBasePrice    = $setBasePrice
        #$setBasePriceLow = ($setBasePrice / $maxVolHigh * $maxVolLow)
    }

    $finalPerUnit = ($setBasePrice / $unitsLow + ($massUnit / 1000) * ($costPer100Km / 100)) * 10

    $priceForKmLow   = $finalPerUnit * $unitsLow / 10
    $priceForKmHigh  = $finalPerUnit * $unitsHigh / 10

    if(-not ([string]::IsNullOrEmpty($cargoCustomSettings.priceFactor))){
        $finalPerUnit = $finalPerUnit * $cargoCustomSettings.priceFactor
    }

    $finalPerUnit = [math]::Round($finalPerUnit,5)

    $priceForKmLow   = $([math]::Round($priceForKmLow,2))
    $priceForKmHigh  = $([math]::Round($priceForKmHigh,2))
    
    if(([string]::IsNullOrEmpty($cargoCustomSettings.unit_load_time))){
        $setLoadTime =
        switch ( $_.group )
        {
            "bulk"         { $loadTimeBulkUnit }
            "liquid"       { $loadTimeLiquidUnit }
            "containers"   { $loadTimeContUnit }
            "refrigerated" { $loadTimeReeferUnit }
            default        { 0 }
        }

        if($setLoadTime -ne 0){
            $setLoadTime      = ($setLoadTime | Measure-Object -Minimum).Minimum
            $_.unit_load_time = [math]::Ceiling($setLoadTime * $_.volume)
        }
    }

    Write-Host "$priceForKmLow €/Km (Low)"
    Write-Host "$priceForKmHigh €/Km (High)"
    if($altMassCalc){ 
        Write-Host "$finalPerUnit €/Unit" -ForegroundColor Yellow
        }else{
        Write-Host "$finalPerUnit €/Unit"
        }
    Write-Host $($_.unit_load_time) "Load Time/Unit" 
    
    #if($_.name -eq '"@@Telehandler@@"')
    #{pause}
    #if($_.overweight)
    #{pause}



    Write-Host "-----------------------------"

    #$addBodyType = @()
    #$ifBodyTypes = $_.body_types
    #switch($addBody){
    #    "container" { 
    #                    if($ifBodyTypes -notcontains "container") { 
    #                        $addBodyType += "container"
    #                        
    #                    }
    #                    if($ifBodyTypes -notcontains "flatbed_cont") { 
    #                        $addBodyType += "flatbed_cont"
    #                        
    #                    }
    #                }
    #}
    #if($addBodyType){$_.body_types += $addBodyType}

    $_.unit_reward_per_km = $finalPerUnit
    $_.priceForKmLow      = $priceForKmLow
    $_.priceForKmHigh     = $priceForKmHigh
    $_.massLow            = $massLow
    $_.massHigh           = $massHigh

}



###############################################################################################
###############################################################################################
###############################################################################################
###############################################################################################
###############################################################################################

$outputPath = Join-Path $outputPath $selector
pause 
$dataSet | % {

    $cargoDlc = $_.dlc

    if($cargoDlc -notin "custom","base" -and -not ([string]::IsNullOrEmpty($cargoDlc))){
        $targetPath = Join-Path (Join-Path $outputPath $cargoDlc) "def/cargo"
    }else{
        $targetPath = Join-Path (Join-Path $outputPath "base") "def/cargo"
    }
    
    if (!(Test-Path $targetPath)) {
        New-Item -Path $targetPath -ItemType Directory -Force | Out-Null
    }

    $outputFilename = $_.fileName
    $fullFilePath   = Join-Path -Path $targetPath -ChildPath $outputFilename

    Set-Content -Path $fullFilePath -NoNewLine -Value "cargo_data: $($_.cargo_data)`n"
    Add-Content -Path $fullFilePath -NoNewLine -Value "{`n"
    Add-Content -Path $fullFilePath -NoNewLine -Value "`tname: $($_.name)`n"

    if($_.fragility){
        Add-Content -Path $fullFilePath -NoNewLine -Value "`tfragility: $($_.fragility)`n"}

    if($_.adr_class){
        Add-Content -Path $fullFilePath -NoNewLine -Value "`tadr_class: $($_.adr_class)`n"}

    if($_.valuable){
        Add-Content -Path $fullFilePath -NoNewLine -Value "`tvaluable: $($_.valuable)`n"}

    if($_.minimum_distance){
        Add-Content -Path $fullFilePath -NoNewLine -Value "`tminimum_distance: $($_.minimum_distance)`n"
    }else{
        Add-Content -Path $fullFilePath -NoNewLine -Value "`tminimum_distance: $minimumdistance`n"
    }

    if($_.maximum_distance){
        Add-Content -Path $fullFilePath -NoNewLine -Value "`tmaximum_distance: $($_.maximum_distance)`n"}

    if($_.overweight){
        Add-Content -Path $fullFilePath -NoNewLine -Value "`toverweight: $($_.overweight)`n"}


    if($_.oversize){
        Add-Content -Path $fullFilePath -NoNewLine -Value "`toversize: $($_.oversize)`n"}


    foreach($j in $_.group){
        Add-Content -Path $fullFilePath -NoNewLine -Value "`tgroup[]: $j`n"
    }

    if($_.prob_coef){
        Add-Content -Path $fullFilePath -NoNewLine -Value "`tprob_coef: $($_.prob_coef)`n"}

    Add-Content -Path $fullFilePath -NoNewLine -Value "`tvolume: $($_.volume)`n"
    Add-Content -Path $fullFilePath -NoNewLine -Value "`tmass: $($_.mass)`n"
    Add-Content -Path $fullFilePath -NoNewLine -Value "`tunit_reward_per_km: $($_.unit_reward_per_km)`n"

    if($_.unit_load_time){
        Add-Content -Path $fullFilePath -NoNewLine -Value "`tunit_load_time: $($_.unit_load_time)`n"
    }

    foreach($j in $_.body_types){
        Add-Content -Path $fullFilePath -NoNewLine -Value "`tbody_types[]: $j`n"
    }

    Add-Content -Path $fullFilePath -NoNewLine -Value "}`n"
}


###############
#Cargo Def erstellen für neue Cargos
if($newCustomData.count){
   
    $targetPath = Join-Path $outputPath "base\def"
    $fileName = ("cargo.SE_CIM.sii").ToLower()
    $cargoInclude = Join-Path -Path $targetPath -ChildPath $fileName 

    Set-Content -Path $cargoInclude -NoNewLine -Value "SiiNunit`n"
    Add-Content -Path $cargoInclude -NoNewLine -Value "{`n"
    foreach($i in $newCustomData.fileName){
        Add-Content -Path $cargoInclude -NoNewLine -Value '@include "'
        Add-Content -Path $cargoInclude -NoNewLine -Value "cargo/$i"
        Add-Content -Path $cargoInclude -NoNewLine -Value '"'
        Add-Content -Path $cargoInclude -NoNewLine -Value "`n"
    }
    Add-Content -Path $cargoInclude -NoNewLine -Value "}`n"
}


<#

$cargoData      = Get-Content $cargoDataFile -Raw | ConvertFrom-Json

$newCustomData | % {
    
    $cargo = $_.sameAsCargo
    $cargo
    $companyIn  = $cargoData | ? { $_.In.Name  -contains $cargo }
    $companyout = $cargoData | ? { $_.Out.Name -contains $cargo }


    $companyIn | % {
        $company = $_.company
        $ifNotOnRemoveList = (@($mergedRemoveList | ? { $_.cargo -eq $cargo -and $_.inCompany.company -notcontains $company })).count
        if($ifNotOnRemoveList){
            $_
        }
    }

    $companyOut | % {
        $company = $_.company
        $ifNotOnRemoveList = (@($mergedRemoveList | ? { $_.cargo -eq $cargo -and $_.outCompany.company -notcontains $company })).count
        if($ifNotOnRemoveList){
            $_
        }
    }
}
#>














Write-Host "----------------------------------------------------- !!! STOPP !!! ----------------------------------------------------------" -ForegroundColor Yellow
pause

#$dataSet | % {
    #$fileName = $($_.cargo_data + "_SE_" + $selector + ".sii").ToLower()
    #$cargoFileName = $_.fileName
    #$cargoInclude = Join-Path -ChildPath $fileName -Path $outputPath

    $fileName = ("cargo.SE_" + $selector + ".sii").ToLower()
    $cargoInclude = Join-Path -ChildPath $fileName -Path $outputPath

    Set-Content -Path $cargoInclude -NoNewLine -Value "SiiNunit`n"
    Add-Content -Path $cargoInclude -NoNewLine -Value "{`n"
    foreach($i in $dataSet.fileName){
        Add-Content -Path $cargoInclude -NoNewLine -Value '@include "'
        Add-Content -Path $cargoInclude -NoNewLine -Value "cargo/$i"
        Add-Content -Path $cargoInclude -NoNewLine -Value '"'
        Add-Content -Path $cargoInclude -NoNewLine -Value "`n"
    }
    Add-Content -Path $cargoInclude -NoNewLine -Value "}`n"

#}















###############################################################################################
###############################################################################################
###############################################################################################
###############################################################################################
###############################################################################################


#$dataSet | ? fileName -EQ "cott_harvest.sui"
if($abcd){


clear
$dataSet.cargo_data



clear
$dataSet | Sort priceForKmLow,massLow | Format-Table -Property fileName,volume,priceForKmLow,priceForKmHigh,unit_reward_per_km,massLow,massHigh

clear
$dataSet | ? body_types -Contains "container" | Format-Table -Property fileName,body_types,volume,unit_load_time




clear
#$dataSet | ? adr_class -eq 1
$adrCargo = $dataSet | ? adr_class -gt 0 #| Format-Table -Property fileName,adr_class,body_types,volume,unit_load_time

$adrCargoBox = $adrCargo | ? adr_class -eq 1
#$adrCargo | ? group -NotContains "bulk" | Format-Table -Property fileName,adr_class,body_types,group

$adrCargoTank = $adrCargo | ? { ($_.group -contains "liquid" -or $_.adr_class -in 2,3) -and $_.fileName -notlike "*_t.sui" } #| Format-Table -Property fileName,adr_class,body_types,group
#$adrCargoTank | Format-Table -Property fileName,adr_class,body_types,group
#$adrCargoTank | ? adr_class -eq 2 | Format-Table -Property fileName,adr_class,body_types,group


$contTemplatesPath = "E:\SpieleExtras\ETS2\Modding\Cargo-Mod\Templates\cargo"
$contTemplates     = (Get-ChildItem -Directory -Path $contTemplatesPath).Name

$adrCargoTank | % {

    $cargoDataName = $_.cargo_data.Split(".")[1]
    $_.contType = $contTemplates | ? { $_ -like "*$cargoDataName" }
    if(!($_.contType)){
        $_.contType = "cont_t_default"
    }
    

    #if( $_.cargo_data.Split(".")[1] -in $contTemplates ){#.Split("_")[2]
    #    $_.cargo_data.Split(".")[1]
    #}
}





$CargoNameDef = @()
$CargoNameDef += Import-Csv -Path "E:\SpieleExtras\ETS2\Modding\Cargo-Mod\csv\CargoNameDef.csv"
$adrCargoTank | % {

    $orgCargoName       = $_.cargo_data.Split(".")[1]
    $orgCargoNameLength = $orgCargoName.Length


    if($CargoNameDef | ? org_name -EQ $orgCargoName){
        $newCargoName = ($CargoNameDef | ? org_name -EQ $orgCargoName).con_name
    }elseif($orgCargoNameLength -lt 10){
        $newCargoName = $orgCargoName + "_xx"
        $_.fileName   = $newCargoName + ".contmod.sui"
        $_.cargo_data = "cargo." + $newCargoName



    } else{
        Write-Host "cargo_data Name to long for + _xx"
        do{
            $newCargoName = Read-Host "$orgCargoName ($orgCargoNameLength)"
        }until ($newCargoName.length -lt 13)

        $addCargoNameDef = [pscustomobject]@{
            org_name = $orgCargoName
            con_name = $newCargoName
        }
        $CargoNameDef += $addCargoNameDef
    }


    if($_.body_types -notcontains "container"){

       $_.mass       = $_.mass * 0.625
       $_.body_types = @("container", "flatbed_cont")

    }
    $_.sameAsCargo = $orgCargoName
}





$adrCargoTank 


























clear
$dataSet | ? { $_.body_types -NotContains "container" -and ($_.group -contains "containers" -or $_.group -contains "refrigerated") } | Format-Table -Property fileName,body_types,group,volume,unit_load_time


clear
$containsC = ""
$containsC = $dataSet | ? fileName -Like "*_c.*"


foreach($i in $containsC){
    foreach($j in $dataSet){
        if($j.fileName -ne $i.fileName){
            $tempName = $j.fileName.Split(".")[0] + "_c"
            #$tempName

            if($i.fileName -like "$tempName*"){
                Write-Host "------------------------------"
                $tempName
                $i
                $j
                Write-Host "------------------------------"
                Write-Host
                Write-Host
                $tempName = ""
                pause
            }
        }
    }
}


###############################################################################################
###############################################################################################
###############################################################################################
###############################################################################################
###############################################################################################


clear
$boxContainers  = $dataSet | ? { ($_.group -eq "containers" -or $_.group -eq "refrigerated") -and $_.body_types -notContains "container" -and $_.fileName -notlike "x_*" }
$tankContainers = $dataSet | ? { $_.group -eq "liquid" -and $_.body_types -notContains "container" -and $_.fileName -notlike "x_*" -and ($_.body_types -Contains "gastank" -or $_.body_types -Contains "chemtank") }
$boxMembers = @("refrigerated","insulated","curtainside","dryvan")




$boxContainersTrue =
foreach($i in $boxContainers){
    $ifBoxOnly = $true

    $checkExistC = ($i.fileName).Split(".")[0] + "_c." + ($i.fileName).Split(".")[1]
    if($checkExistC -in $dataSet.fileName){
       continue
    }

    foreach($j in $i.body_types){
        if($j -in  $boxMembers){
            #$true
            #$i
            #break
        }else{
            $ifBoxOnly = $false
            break
        }
    }
    if($ifBoxOnly){
        $i
    }
}






$tankContainersTrue =
foreach($i in $tankContainers){
    $ifBoxOnly = $true

    $checkExistC = ($i.fileName).Split(".")[0] + "_c." + ($i.fileName).Split(".")[1]
    if($checkExistC -in $dataSet.fileName){
        Write-Host "$checkExistC"
        pause
       continue
    }

    #foreach($j in $i.body_types){
    #    if($j -in  $boxMembers){
    #        #$true
    #        #$i
    #        #break
    #    }else{
    #        $ifBoxOnly = $false
    #        break
    #    }
    #}
    if($ifBoxOnly){
        $i
        #$contVol = 80
        #$i.mass * 0.625 #* $i.volume
        #$tankContainerVolUnit = ($contVol / $i.volume * $i.mass * 0.625 / $contVol) * $i.volume
        #$tankContainerVolUnit

    }
}


$boxTare40 = 3950
$refTare40 = 4575
$boxTare45 = 4320

$CargoNameDef = @()
$CargoNameDef += Import-Csv -Path "E:\SpieleExtras\ETS2\Modding\Cargo-Mod\csv\CargoNameDef.csv"
foreach($c in $boxContainersTrue){

    if(($c.body_types.Count -eq 2 -and ($c.body_types -contains "refrigerated" -and $c.body_types -contains "insulated")) -or
    ($c.body_types.Count -eq 1 -and ($c.body_types -contains "refrigerated" -or $c.body_types -contains "insulated")) ){

        #Write-Host "refrigerated Only!"
        $c.mass = $([math]::Round($c.mass * 0.8805,1))
        $c.contType = "ref"
       #pause
    } elseif($c.body_types.Count -eq 1 -and $c.body_types -contains "curtainside") {
        $c.contType = "curt"
    } else {
        $c.contType = "box"
    }
    
    #continue
    #$c
    
    $orgCargoName       = ($c.cargo_data).Split(".")[1]
    $orgCargoNameLength = $orgCargoName.length
    if($orgCargoNameLength -gt 10){
        


        if($CargoNameDef | ? org_name -EQ $orgCargoName){
            $newCargoName = ($CargoNameDef | ? org_name -EQ $orgCargoName).con_name
        }else{

            #$c.cargo_data
            #continue
            Write-Host "cargo_data Name to long for + _c"
            do{
                $newCargoName = Read-Host "$orgCargoName ($orgCargoNameLength)"
            }until ($newCargoName.length -lt 13)

            $addCargoNameDef = [pscustomobject]@{
                org_name = $orgCargoName
                con_name = $newCargoName
            }
            $CargoNameDef += $addCargoNameDef
        }
        

    }else{
        $newCargoName = ($c.cargo_data).Split(".")[1]+"_c"
    }

    $c.fileName       = $newCargoName + ".contmod.sui"
    $c.cargo_data     = "cargo."+$newCargoName
    $c.unit_load_time = [math]::Ceiling($c.volume * $loadTimeContainer)
    $c.body_types     = @("container","flatbed_cont")
    $c.sameAsCargo    = $orgCargoName
}

$CargoNameDef | Export-Csv -Path "E:\SpieleExtras\ETS2\Modding\Cargo-Mod\csv\CargoNameDef.csv"

$dataSet = $boxContainersTrue
$outputPath  = "E:\SpieleExtras\ETS2\Modding\Cargo-Mod\Cont"


$dataSet = $tankContainersTrue
$outputPath  = "E:\SpieleExtras\ETS2\Modding\Cargo-Mod\Tank"


foreach ($i in $dataSet){

    $cargoName = ($i.cargo_data).Split(".")[1]
    $contType  = "cont_"+$i.contType

    $sourceDirectory  = "E:\SpieleExtras\ETS2\Modding\Cargo-Mod\Templates\cargo\$contType\"
    $destinationDirectory = "E:\SpieleExtras\ETS2\Modding\Cargo-Mod\Tank\cargo\$cargoName"

    Copy-item -Force -Recurse -Verbose $sourceDirectory -Destination $destinationDirectory
}

clear






$companyCargo = "E:\SpieleExtras\ETS2\Modding\Cargo-Mod\Tank\company"

$contCompanys = @("cont_port","cont_port_it","adrica","dunavia","cont_port_fr","port_de_conteneur","ts_atlas","ot_port","bct")

foreach($i in $dataSet){

    Write-Host "Erstelle In/Out Liste ($($i.sameAsCargo)) ..."

    $companysIn = ($companyInOut | ? In -Contains $i.sameAsCargo).company
    $companysOut = ($companyInOut | ? Out -Contains $i.sameAsCargo).company

    $companysIn  += $contCompanys
    $companysOut += $contCompanys

    $companysIn  = $companysIn | sort | Get-Unique
    $companysOut = $companysOut | sort | Get-Unique

    Write-Host "Erstelle In defenition Dateien ..."

    foreach($in in $companysIn){
        
        $cargoName  = $i.cargo_data.Split(".")[1]

        $fileTarget = $companyCargo + "\$in\in\$cargoName.contmod.sii"

        $gehZuNull = New-Item -Path $fileTarget -Force

        Set-Content -Path $fileTarget -NoNewLine -Value "SiiNunit`n"
        Add-Content -Path $fileTarget -NoNewLine -Value "{`n"
        Add-Content -Path $fileTarget -NoNewLine -Value "cargo_def : .$cargoName {`n"
        Add-Content -Path $fileTarget -NoNewLine -Value ' cargo: "cargo.'
        Add-Content -Path $fileTarget -NoNewLine -Value $cargoName
        Add-Content -Path $fileTarget -NoNewLine -Value '"'
        Add-Content -Path $fileTarget -NoNewLine -Value "`n}`n"
        Add-Content -Path $fileTarget -NoNewLine -Value "}`n"

        #SiiNunit
        #{
        #cargo_def : .lpg {
        # cargo: "cargo.lpg"
        #}
        #}
    }

    Write-Host "Erstelle Out defenition Dateien ..."

    foreach($out in $companysOut){
        
        $cargoName  = $i.cargo_data.Split(".")[1]

        $fileTarget = $companyCargo + "\$out\out\$cargoName.contmod.sii"

        $gehZuNull = New-Item -Path $fileTarget -Force

        Set-Content -Path $fileTarget -NoNewLine -Value "SiiNunit`n"
        Add-Content -Path $fileTarget -NoNewLine -Value "{`n"
        Add-Content -Path $fileTarget -NoNewLine -Value "cargo_def : .$cargoName {`n"
        Add-Content -Path $fileTarget -NoNewLine -Value ' cargo: "cargo.'
        Add-Content -Path $fileTarget -NoNewLine -Value $cargoName
        Add-Content -Path $fileTarget -NoNewLine -Value '"'
        Add-Content -Path $fileTarget -NoNewLine -Value "`n}`n"
        Add-Content -Path $fileTarget -NoNewLine -Value "}`n"

        #SiiNunit
        #{
        #cargo_def : .lpg {
        # cargo: "cargo.lpg"
        #}
        #}
    }

    Write-Host
    Write-Host
    Write-Host "----------------------------------------------"
}












}
















