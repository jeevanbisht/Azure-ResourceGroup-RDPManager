<# 
 
.SYNOPSIS
	LabManager.ps1 is a Windows PowerShell script to create a RDG for Azure Resource Group based Virtual Machines with use with Remote Desktop Connection Manager
.DESCRIPTION
	Version: 1.0.0
	LabManager.ps1  is a Windows PowerShell script to connect to Azure Subscription and enumerate all ResourceGroups.
    For all the powered up VMs in a particular Resource Groups it creates am RDG file to help connect with Virtual Machines.
    This is helpful for Lab ennviorment where you might be switching off the Virtual Machines, having a new public IPs when you power them backon.
    The .RDG is located in c:\RDP folder. check the DEMO video for more info.
    
.DISCLAIMER
	THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF
	ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO
	THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
	PARTICULAR PURPOSE.
#> 
## Paramaters 
$AzureSubscription = "GTP - Jeevan Bisht"  
$RDPAccount ="GTPADMIN"
$RDPPassword = "p1"
$RDPDomain = "JBLAB"
$RDPFilePath="C:\RDP"

if( -Not (Test-Path -Path $RDPFilePath ) )
{
    New-Item -ItemType directory -Path $RDPFilePath
}

connect-azureRMAccount
Select-AzureRMSubscription -Subscription $AzureSubscription
Function Get-AzureADResourceGroup
{
     [CmdletBinding()]
	param(
		[bool] $ForceConnect,
        [string] $AzureSubscriptionName
	)

    if($ForceConnect -eq $true)
     {    
       connect-azurermaccount -Subscription $AzureSubscriptionName
     }        
    
        $Error1
        $resourceGroups=get-azureRMResourceGroup -ErrorVariable $Error1 -ErrorAction SilentlyContinue

        if($Error1 -ne 0)
        {
          connect-azurermaccount -Subscription $AzureSubscriptionName  
          $resourceGroups=get-azureRMResourceGroup -ErrorVariable $Error1
        }
     

    $resourceGroupNames=@()
    foreach($resourceGroup in $resourceGroups)
    {
        $resourceGroupNames=$resourceGroupNames+$resourceGroup.ResourceGroupName
    }

    $resourceGroupNames
    return

}
#Build the GUI


[xml]$xaml = @"
<Window 
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        xmlns:local="clr-namespace:PSS"
        Title="GTP RDP Helper" Height="384.12" Width="530.687">
    <Grid>
        <Button x:Name="ConnectButton" Content="Connect" HorizontalAlignment="Left" Margin="29,314,0,0" VerticalAlignment="Top" Width="75"/>
        <Button x:Name="GenerateButton" Content="Generate" HorizontalAlignment="Left" Margin="123,314,0,0" VerticalAlignment="Top" Width="75"/>
        <ListBox x:Name="ResourceGroupList" HorizontalAlignment="Left" Height="247" Margin="29,47,0,0" VerticalAlignment="Top" Width="475"/>
        <Label Content="Resource Groups" HorizontalAlignment="Left" Height="32" Margin="29,15,0,0" VerticalAlignment="Top" Width="127"/>

    </Grid>
</Window>
"@
$reader=(New-Object System.Xml.XmlNodeReader $xaml)
$Window=[Windows.Markup.XamlReader]::Load( $reader )

#Connect to Controls 
$ConnectButton = $Window.FindName("ConnectButton")
$GenerateButton = $Window.FindName("GenerateButton")
$List = $Window.FindName("ResourceGroupList")


#Add All the Resource Group Names to the List
$ConnectButton.Add_Click({

    #Clear the List 
    $List.items.Clear()

    #$var=Get-AzureADResourceGroup -ForceConnect $false -AzureSubscriptionName "GTP - Jeevan Bisht"
    $ResourceGroups = Get-AzureRmResourceGroup   |  Select-Object ResourceGroupName
    foreach( $ResourceGroup in $ResourceGroups)
        {
            $List.items.Add($ResourceGroup.ResourceGroupName.ToUpper()) 
        }
           
    })

#Generate the RDG File
$GenerateButton.Add_Click({

[string]$ResourceGroup=$List.SelectedItem.ToUpper()
[string]$RDPFileName=$RDPFilePath +"\" +  $ResourceGroup + ".rdg"
$VirtualMachines = (Get-AzureRmPublicIpAddress -ResourceGroupName $ResourceGroup).where({$PSItem.IpAddress -ne 'Not Assigned'})

$RDPDomain=$List.SelectedItem.ToString()

$rdpHeader = @"
<?xml version="1.0" encoding="utf-8"?>
<RDCMan programVersion="2.7" schemaVersion="3">
  <file>
   <credentialsProfiles />
   <properties>
    <expanded>True</expanded>
    <name>$ResourceGroup</name>
   </properties>
   <logonCredentials inherit="None">
    <profileName scope="Local">Custom</profileName>
    <userName>$RDPAccount</userName>
    <password>$RDPPassword</password>
    <domain>$RDPDomain</domain>
   </logonCredentials>
   <remoteDesktop inherit="None">
    <sameSizeAsClientArea>True</sameSizeAsClientArea>
    <fullScreen>False</fullScreen>
    <colorDepth>24</colorDepth>
   </remoteDesktop>
   <displaySettings inherit="None">
    <liveThumbnailUpdates>True</liveThumbnailUpdates>
    <allowThumbnailSessionInteraction>False</allowThumbnailSessionInteraction>
    <showDisconnectedThumbnails>True</showDisconnectedThumbnails>
    <thumbnailScale>7</thumbnailScale>
    <smartSizeDockedWindows>False</smartSizeDockedWindows>
    <smartSizeUndockedWindows>False</smartSizeUndockedWindows>
   </displaySettings>
"@ 


$rdpTail= @"
</file>
</RDCMan>
"@

$rdpServers=""

foreach($VirtualMachine in $VirtualMachines)
    {
    $IpAddress = $VirtualMachine.IpAddress
    [string]$VMName = $VirtualMachine.Name
    $VMName=$VMName.Substring(0,$VMName.Length-3).ToUpper()
    
    #$List.items.Add($VMName)
    $rdpServers=$rdpServers + @"
    <server>
     <properties>
      <displayName> $VMName</displayName>
      <name>$IpAddress</name>
     </properties>
    </server>
"@
    }

     $RDPFile =""
     $RDPFile= $rdpHeader + $rdpServers
     $RDPFile=$RDPFile+ $rdpTail

     
     Set-Content -Path $RDPFileName  -Value $RDPFile  -Force
     [System.Windows.MessageBox]::Show($List.SelectedItem + " VMGroup is exported !!")

})

$Window.ShowDialog() 
