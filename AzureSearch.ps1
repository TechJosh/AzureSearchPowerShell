$global:UrlBase=""
$global:Headers=@{}
$global:IndexName=""

Function Init() {
    $json = Get-Content 'appSettings.json' | Out-String | ConvertFrom-Json
    
    $global:UrlBase = $json.SearchServiceUrl.Trim('/')

    $global:Headers = @{
        'api-key' = $json.SearchServiceAdminApiKey
        'Content-Type' = 'application/json' 
        'Accept' = 'application/json'
    }

    $global:IndexName = $json.SearchIndexName
}
Function Help() {
    $cmds = 
    @(
        [PsCustomObject]@{Command="Help";Description="Show this table"},
        [PsCustomObject]@{Command="Create";Description="Create new a new index"},
        [PsCustomObject]@{Command="Load";Description="Loads the documents into the index"},
        [PsCustomObject]@{Command="Weights";Description="Adds weight scoring to the index"},
        [PsCustomObject]@{Command="Search";Description="Searches the index documents"},
        [PsCustomObject]@{Command="Exit";Description="Exit the program"}
    )

    $cmds | ForEach-Object {[PsCustomObject]$_} | Format-Table -AutoSize
}

Function Create() {

    Write-Host "Formatting Index..."

    $body = @"
{
    "name": "$IndexName",
    "fields": [
        {"name": "Id", "type": "Edm.String", "key": true, "filterable": true},
        {"name": "City", "type": "Edm.String", "searchable": true, "filterable": false, "sortable": true, "facetable": false},
        {"name": "Region", "type": "Edm.String", "searchable": true, "filterable": false, "sortable": true, "facetable": false},
        {"name": "Country", "type": "Edm.String", "searchable": true, "filterable": false, "sortable": true, "facetable": false}
    ]
}
"@

    $Url = $global:UrlBase + '/indexes/' + $global:IndexName + '?api-version=2019-05-06'

    Write-Host "Creating Index..."

    Invoke-RestMethod -Uri $Url -Headers $global:Headers -Method Put -Body $body

}

Function Load() {
    Write-Host "Loading Data from file..."

    $body = Get-Content 'entities.json' -Raw

    Write-Host "Formatting Request"

    $Url = $global:UrlBase + '/indexes/' + $global:IndexName + '/docs/index?api-version=2019-05-06'

    Write-Host "Sending Payload"

    Invoke-RestMethod -Uri $Url -Headers $global:Headers -Method Post -Body $body
}

Function Weights() {

    $Url = $global:UrlBase + '/indexes/' + $global:IndexName + '?api-version=2019-05-06'

    Write-Host "Loading Index..."

    $response = Invoke-RestMethod -Uri $Url -Headers $global:Headers -Method Get | ConvertTo-Json -depth 32

    Write-Host "Updating Index..."

    $obj = $response | ConvertFrom-Json

    $json = @"
        {  
          "name": "Default",  
          "text": {  
            "weights": { 
              "City": 10,
              "Region": 5,
              "Country": 1
            }
          },  
          "functions": [],  
          "functionAggregation": "sum"
        }
"@
    $xx = $json | ConvertFrom-Json;

    $obj.scoringProfiles = @($xx)
    $obj.defaultScoringProfile = "Default"

    $body = $obj | ConvertTo-Json -depth 32

    Write-Host "Sending Update..."

    Invoke-RestMethod -Uri $Url -Headers $global:Headers -Method Put -Body $body
}

Function Search() {

    $term = Read-Host "Enter Search Term (use * for wildcard)"

    $Url = $global:UrlBase + '/indexes/' + $global:IndexName + '/docs?api-version=2019-05-06&search=' + $term + '&$count=true'

    $results = Invoke-RestMethod -Uri $url -Headers $headers | ConvertTo-Json

    $obj = $results | ConvertFrom-Json

    $count = $obj."@odata.count"

    Write-Host "Displaying $count results"

    $obj.value  | ForEach-Object {$_} | Format-Table -AutoSize
}

Function Main() {
    Init
    Help

    $run = $true
    while ($run) {
        $val = Read-Host "Command"
        $val = $val.Trim().ToLower()
        switch ($val) {
            "help" { Help; Break }
            "exit" { $run = $false; Break }
            "create" { Create; Break }
            "load" { Load; Break }
            "weights" { Weights; Break }
            "search" { Search; Break }
            default { Write-Host "Invalid Command." }
        }
    }
}

Main