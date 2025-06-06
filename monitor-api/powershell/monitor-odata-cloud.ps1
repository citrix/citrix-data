#requires -version 3

<#
    Get Monitor data using the OData API (Cloud setup)
#>

<#
.SYNOPSIS

Send queries to Citrix Cloud and return/write the results back as JSON or CSV objects

.PARAMETER customerId

The Citrix Cloud customerid

.PARAMETER outputfile

Name and path to write output to. If it exists, use -overwrite to overwrite.
Pseudo environment variables like %day% and %month% can be used in the folder and/or file name and will be created as necessary

.PARAMETER overwrite

If specified as "yes", any existing output file will be overwritten otherwise the script will fail if the outoput file already exists

.PARAMETER format

The output format to use. If not specified it will be determined from the output file extension

.PARAMETER outputEncoding

The output encoding to use. Defaults to UTF8

.PARAMETER query

The ODATA query

.PARAMETER maximumItems

The maximum number of items to return although as results are returned in pages, it may be slightly more than this number

.PARAMETER clientId

The client id to be used to authenticate to Citrix DaaS (usually a GUID)

.PARAMETER clientSecret

The client secret for the client id specified by -clientId to authenticate to Citrix DaaS




.EXAMPLE

'.\<script>' -customerId <customerId> -clientId <clientId> -clientSecret <clientSecret> -query "Users" -outputFile out.json -format json -overWrite yes -Verbose

Get list of users

.EXAMPLE

'.\<script>' -customerId <customerId> -clientId <clientId> -clientSecret <clientSecret> -query "Applications?`$filter=LifecycleState eq 0&`$count=true" -outputFile c:\logs\%year%\%monthname%\citrix.odata.%hour.%minute%.%second%.csv

Get active applications

.NOTES

Reference:
https://developer-docs.citrix.com/en-us/monitor-service-odata-api

Reference:
https://github.com/guyrleech/Citrix/blob/master/Get%20Citrix%20OData%20data.ps1

In the queries below, you need to escape all '$' characters in the query with the use of '`', e.g. '`$count'
You also need to replace any placeholder values (e.g. {start_time}) with an actual value, possibly calculated within the script.


Other Examples:

- Citrix DaaS ICA Round Trip Time (RTT)
  This is the time interval measured at the client between the first step (user action) and the last step (graphical response displayed). This metric can be thought of as a measurement of the screen lag that a user experiences while interacting with an application hosted in a session.
  URL: SessionMetrics?$filter=CollectedDate gt {start_time} and IcaRttMS gt 0&$select=CollectedDate,IcaRttMS&$expand=Session($select=ConnectionStateChangeDate;$expand=User($select=upn),Machine($select=DnsName))

  Session RTT?
  SessionMetrics?$filter=(SessionId eq $SessionKey)

- Session summary
  Hourly summary of session counts by delivery group.
  URL: SessionActivitySummaries?$filter=Granularity eq 60 and SummaryDate gt {start_time}&$select=SummaryDate,ConnectedSessionCount,DisconnectedSessionCount,ConcurrentSessionCount&$expand=DesktopGroup($select=Id,Name)

  Includes session usage?

- Application launches
  URL: ApplicationInstances?$filter=(StartDate gt {start_time})&$select=StartDate&$expand=Session($select=SessionType;$expand=User($select=upn),Machine($select=DnsName),Connections($select=ClientName,ClientPlatform,ClientVersion,ConnectedViaIPAddress)),Application($select=Name)"

- Desktop launches
  URL: Connections?$filter=(LogOnStartDate gt {start_time})&$select=LogOnStartDate,ClientName,ClientPlatform,ClientVersion,ConnectedViaIPAddress&$expand=Session($filter=SessionType eq 0;$select=SessionType;$expand=User($select=upn),Machine($select=DnsName))"

- VDA Availability
  Hourly summary of VDA availability by delivery group.
  URL: MachineSummaries?$filter=Granularity eq 60 and SummaryDate gt {start_time}&$select=SummaryDate,PoweredOnMachinesCount,RegisteredMachinesCount,MachinesInMaintenanceModeCount,MachinesCount&$expand=DesktopGroup($select=Id,Name)"

  Can include Machines in a failure state?

- Machine CPU, Memory and disk usage (during a user session)
    ResourceUtilization?$filter=MachineID eq $MachineID and CollectedDate gt $SessionStartDate and CollectedDate lt $SessionEndDate

- Last logon time for a user session
    Sessions?$filter=(CreatedDate gt $CreatedDate) and (User/Username eq 'MYUSER')&$expand=User($select=username,upn),Connections($select=LogonStartDate,ClientName,ConnectedViaIPAddress;$OrderBy=LogonStartDate Desc;$top=1)&OrderBy=StartDate Desc&$top=1


#>

[CmdletBinding()]
Param
(
    [Parameter(ParameterSetName='cloud',Mandatory=$false)]
    [string]$customerid ,
    [Parameter(ParameterSetName='cloud',Mandatory=$false)]
    [string]$clientId ,
    [Parameter(ParameterSetName='cloud',Mandatory=$false)]
    [string]$clientSecret ,
    [string]$query ,
    [int]$maximumItems = 0 ,
    [ValidateSet('csv','json')]
    [string]$format = 'csv' ,
    [ValidateSet( 'String' , 'Unicode' , 'Byte' , 'BigEndianUnicode' , 'UTF8' , 'UTF7' , 'UTF32' , 'Ascii' , 'Default' , 'Oem' , 'BigEndianUTF32' )]
    [string]$outputEncoding = 'UTF8' ,
    [ValidateSet('Yes','No')]
    [string]$overWrite = 'No' ,
    [string]$csvOutputDelimiter = ',',
    [string]$outputFile , 
    [string]$baseCloudURL =  'https://api-us.cloud.com/monitorodata' ,
    [int]$oDataVersion = 4 ,
    [int]$retryMilliseconds = 1000 ,
    [switch]$AllowUnencryptedAuthentication
)

# $VerbosePreference="Continue"


#region Functions

Function Get-BearerToken {
    ## https://developer.cloud.com/citrix-cloud/citrix-cloud-api-overview/docs/get-started-with-citrix-cloud-apis#bearer_token_tab_oauth_2.0_flow
    param (
        [Parameter(Mandatory=$true)][string]
        $clientId,
        [Parameter(Mandatory=$true)][string]
        $clientSecret
    )
    [string]$bearerToken = $null
    [hashtable]$body = @{
        'grant_type' = 'client_credentials'
        'client_id' = $clientId
        'client_secret' = $clientSecret
    }
    
    $response = $null
    try
    {
        $startRequestTime = [datetime]::Now
        Write-Verbose -Message "$($startRequestTime.ToString('G')): sending auth request"
        $response = Invoke-RestMethod -Uri 'https://api-us.cloud.com/cctrustoauth2/root/tokens/clients' -Method POST -Body $body
        $endRequestTime = [datetime]::Now
    }
    catch
    {
        $endRequestTime = [datetime]::Now
        Throw $_
    }

    if( $null -ne $response )
    {
        $bearerToken = "CwsAuth Bearer=$($response | Select-Object -expandproperty access_token)"
        Write-Verbose -Message "$($startRequestTime.ToString('G')): auth seems ok"
    }
    ## else will have output error
    $bearerToken ## return    
}

#endregion Functions


if( -Not [string]::IsNullOrEmpty( $outputFile ) )
{
    ## format not specified so get from output file extension
    if( -not $PSBoundParameters[ 'format' ] )
    {
        try
        {
            $format = $outputFile -replace '^.*\.(\w+)$' , '$1'
        }
        catch
        {
            Throw "Cannot determine a supported output format from output file extension on $outputFile"
        }
    }

    if( $outputFile.IndexOf( '%' ) -ne $outputFile.LastIndexOf( '%' ) )
    {
        $now = [datetime]::Now
        $outputFile = $outputFile -replace '%year%' , $now.ToString( 'yyyy' ) -replace '%month%' , $now.ToString( 'MM' ) -replace '%day%' , $now.ToString( 'dd') -replace '%monthname%' , $now.ToString( 'MMMM' ) -replace '%dayname%' , $now.ToString( 'dddd') `
            -replace '%hours?%' , $now.ToString( 'HH')  -replace'%minutes?%' , $now.ToString( 'mm') -replace '%seconds?%'
        [string]$logFolder = Split-Path -Path $outputFile -Parent
        Write-Host $logFolder
        if( (-Not [string]::IsNullOrEmpty( $logFolder )) -and (-Not ( Test-Path -Path $logFolder -PathType Container )))
        {
            if( -Not( New-Item -Path $logFolder -ItemType Directory -Force ) )
            {
                Write-Warning -Message "Failed to create log folder $logFolder"
            }
        }
    }
    
    if( (Test-Path -Path $outputFile) -and $overwrite -ine 'yes' )
    {
        Throw "Cannot proceeed as output file `"$outputFile`" already exists and -overwrite not used"
    }
}

[hashtable]$outputProcessors = @{
    'csv' =    @{ Command = 'ConvertTo-csv'  ; Arguments = @{ 'NoTypeInformation' = $true ; 'Delimiter' = $csvOutputDelimiter } }
    'json' =   @{ Command = 'ConvertTo-Json' ; Arguments = @{ 'Depth' = 10 } }
}

if( $outputProcessor = $outputProcessors[ $format ] )
{
    $outputCommand = $outputProcessor.Command
    $outputArguments = $outputProcessor.Arguments
}
else
{
    Throw "Unsupported output format $format"
}



[hashtable]$params = @{}

if( -Not $PSBoundParameters[ 'authtoken' ] )
{
    if( -Not [string]::IsNullOrEmpty( $clientId ) ) ## don't use Remote PS SDK or use -clientId and -clientSecret
    {
        $authtoken = Get-BearerToken -clientId $clientId -clientSecret $clientSecret
    }
    else
    {
         Throw "Please specify -clientId and -clientSecret"
    }
    if( -Not $? -or [string]::IsNullOrEmpty( $authtoken ) )
    {
        Throw "Failed to get authentication token for customer id $customerid"
    }
}
$params.Add( 'Headers' , @{ 'Citrix-CustomerId' = $customerid ; 'Authorization' = $authtoken } )
$protocol = 'https'

$updated_query = $query -replace '\`' , ''
$params[ 'Uri' ] = "$baseCloudURL/$updated_query"
Write-Verbose "URL : $($params.Uri)"


[int]$exitNow = 0
[array]$data = @( do
{
    try
    {
        [int]$results = 0
        [int]$requests = 0
        [string]$lasturi = $params.uri
        [bool]$firstQuery = $true
        [int]$countOfItems = 0

        do
        {
            $requests++
            $resultsPage = $null
            $resultsPage = Invoke-RestMethod @params

            if( $null -ne $resultsPage )
            {
                if( $firstQuery )
                {
                    if( $resultsPage.psobject.Properties[ '@odata.count' ] )
                    {
                        $countOfItems = $resultsPage.'@odata.count'
                        Write-Verbose -Message "$countOfItems items fetched"
                    }
                    $firstQuery = $false
                }
                $results += ( $resultsPage | Select-Object -ExpandProperty Value | Measure-Object).Count
                # $resultsPage.'odata.Value'

                $resultsPage | Select-Object -ExpandProperty Value

                ## https://support.citrix.com/article/CTX312284
                if( $resultsPage.PSObject.Properties['@odata.nextLink' ] -and -not [string]::IsNullOrEmpty( $resultsPage.'@odata.nextLink' ) )
                {
                    $params.uri = $resultsPage.'@odata.nextLink' ## -replace [regex]::Escape( $countQuery )
                    ## prevent infinite loop if something goes wrong
                    if( $params.uri -ne $lasturi )
                    {
                        Write-Verbose -Message "More data available ($($countOfItems - $results)), fetching from $($params.uri)"
                        $lasturi = $params.uri
                    }
                    else
                    {
                        Write-Warning -Message "Next link $lasturi is the same as the previous one so aborting loop"
                        break
                    }
                }
                else ## no further results available so quit loop
                {
                    break
                }
            }
        } while( $resultsPage -and ( $maximumItems -le 0 -or $results -lt $maximumItems ))
        Write-Verbose -Message "Got $results query results in total across $requests requests"
            
        $fatalException = $null
        break ## since call(s) succeeded so that we don't report for lower versions
    }
    catch
    {
        $fatalException = $_
        if( $fatalException.Exception.Response.StatusCode -eq 429 ) ##  Too Many Requests
        {
            Write-Verbose -Message "$(Get-Date -Format G) : too many requests error so will retry after $($retryMilliseconds)ms"
            Start-Sleep -Milliseconds $retryMilliseconds
        }
        else ## something unrecoverable so exit loop
        {
            $exitNow = 1
        }
    }
} while ( $exitNow -eq 0 ) )

if( $fatalException )
{
    Throw $fatalException
}

if( $data -and $data.Count )
{
    Write-Verbose -Message "Got $($data.Count) results"

    $finalOutput = $data | . $outputCommand @outputArguments ## output to stdout

    if( [string]::IsNullOrEmpty( $outputFile ) )
    {
        $finalOutput
    }
    else
    {
        $written = $null
        $finalOutput | Set-Content -Path $outputFile -Encoding $outputEncoding
        if( $? )
        {
            Write-Verbose -Message "Wrote $($finalOutput.Length) items to `"$outputFile`""
        }
    }
}
else
{
    Write-Warning "No data returned"
}
