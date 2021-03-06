$global:vCheckPath = $MyInvocation.MyCommand.Definition | Split-Path

function Get-VCheckPlugin
{
    <#
        .SYNOPSIS
        
        Retrieves installed vCheck plugins and available plugins from the Virtu-Al.net repository.

        .DESCRIPTION
        
        Get-VCheckPlugin parses your vCheck plugins folder, as well as searches the online plugin respository in Virtu-Al.net.
        After finding the plugin you are looking for, you can download and install it with Add-vCheckPlugin. Get-vCheckPlugins
        also supports finding a plugin by name. Future version will support categories (e.g. Datastore, Security, vCloud)
        
        .PARAMETER name

        Name of the plugin.

        .EXAMPLE

        Get list of all vCheck Plugins

        Get-VCheckPlugin

        
        .EXAMPLE

        Get plugin by name

        Get-VCheckPlugin PluginName


        .EXAMPLE

        Get 

        Get-VCheckPlugins PluginName

    #>
    [CmdletBinding()]
    Param
    (
        [Parameter(mandatory=$false)] [String]$name,
        [Parameter(mandatory=$false)] [Switch]$installed,
        [Parameter(mandatory=$false)] [Switch]$notinstalled
    )
    Process
    {
        $pluginObjectList = @()

        foreach ($localPluginFile in (Get-ChildItem $vCheckPath\Plugins\*.ps1))
        {
            $localPluginContent = Get-Content $localPluginFile
            
            if ($localPluginContent | Select-String -pattern "title")
            {
                $localPluginName = ($localPluginContent | Select-String -pattern "Title").toString().split("`"")[1]
            }
            if($localPluginContent | Select-String -pattern "description")
            {
                $localPluginDesc = ($localPluginContent | Select-String -pattern "description").toString().split("`"")[1]
            }
            elseif ($localPluginContent | Select-String -pattern "comments")
            {
                $localPluginDesc = ($localPluginContent | Select-String -pattern "comments").toString().split("`"")[1]
            }
            if ($localPluginContent | Select-String -pattern "author")
            {
                $localPluginAuthor = ($localPluginContent | Select-String -pattern "author").toString().split("`"")[1]
            }
            if ($localPluginContent | Select-String -pattern "version")
            {
                $localPluginVersion = @($localPluginContent | Select-String -pattern "version")[0].toString().split(" ")[-1]
            }
            $pluginObject = New-Object PSObject
            $pluginObject | Add-Member -MemberType NoteProperty -Name name -value $localPluginName
            $pluginObject | Add-Member -MemberType NoteProperty -Name description -value $localPluginDesc
            $pluginObject | Add-Member -MemberType NoteProperty -Name author -value $localPluginAuthor
            $pluginObject | Add-Member -MemberType NoteProperty -Name version -value $localPluginVersion
            $pluginObject | Add-Member -MemberType NoteProperty -Name status -value "Installed"
            $pluginObject | Add-Member -MemberType NoteProperty -Name location -Value $LocalpluginFile.name
            $pluginObjectList += $pluginObject
        }

        if (!$installed)
        {
            try
            {
                $webClient = new-object system.net.webclient
                $response = $webClient.openread("http://www.virtu-al.net/vcheck/plugins/plugins.xml")
                $streamReader = new-object system.io.streamreader $response
                [xml]$plugins = $streamReader.ReadToEnd()

                foreach ($plugin in $plugins.pluginlist.plugin)
                {
                    if (!($pluginObjectList | where {$_.name -eq $plugin.name}))
                    {
                        $pluginObject = New-Object PSObject
                        $pluginObject | Add-Member -MemberType NoteProperty -Name name -value $plugin.name
                        $pluginObject | Add-Member -MemberType NoteProperty -Name description -value $plugin.description
                        $pluginObject | Add-Member -MemberType NoteProperty -Name author -value $plugin.author
                        $pluginObject | Add-Member -MemberType NoteProperty -Name version -value $plugin.version
                        $pluginObject | Add-Member -MemberType NoteProperty -Name status -value "Not Installed"
                        $pluginObject | Add-Member -MemberType NoteProperty -name location -value $plugin.href
                        $pluginObjectList += $pluginObject
                    }
                }
            }
            catch [System.Net.WebException]
            {
                write-error $_.Exception.ToString()
                return
            }

        }

        if ($name)
        {
            $pluginObjectList | where {$_.name -eq $name}
        }
        else
        {
            if($notinstalled)
            {
                $pluginObjectList | where {$_.status -eq "Not Installed"}
            }
            else
            {
                $pluginObjectList
            }

        }
    }

}


function Add-VCheckPlugin
{
    <#
        .SYNOPSIS
        
        Installs a vCheck plugin from the Virtu-Al.net repository.

        .DESCRIPTION
        
        Add-VCheckPlugin downloads and installs a vCheck Plugin (currently by name) from the Virtu-Al.net repository. 
        
        The downloaded file is saved in your vCheck plugins folder, which automatically adds it to your vCheck report. vCheck plugins may require
        configuration prior to use, so be sure to open the ps1 file of the plugin prior to running your next report. 

        
        .PARAMETER name

        Name of the plugin.

        .EXAMPLE

        Install via pipeline from Get-VCheckPlugins

        Get-VCheckPlugin "Plugin name" | Add-VCheckPlugin

        
        .EXAMPLE

        Install Plugin by name

        Add-VCheckPlugin "Plugin name"

    #>
    [CmdletBinding(DefaultParametersetName="name")]
    Param
    (
        [Parameter(parameterSetName="name",Position=0,mandatory=$true)] [String]$name,
        [Parameter(parameterSetName="object",Position=0,mandatory=$true,ValueFromPipeline=$true)] [PSObject]$pluginobject
    )
    Process
    {
        if($name)
        {
            Get-VCheckPlugin $name | Add-VCheckPlugin
        }
        elseif ($pluginObject)
        {
            Add-Type -AssemblyName System.Web
            $filename = $pluginObject.location.split("/")[-1]
            $filename = [System.Web.HttpUtility]::UrlDecode($filename)
            try
            {
                Write-Host "Downloading File..."
                $webClient = new-object system.net.webclient
                $webClient.DownloadFile($pluginObject.location,"$vCheckPath\Plugins\$filename")
                Write-Host -ForegroundColor green "The plugin `"$($pluginObject.name)`" has been installed to $vCheckPath\Plugins\$filename"
                Write-Host -ForegroundColor green "Be sure to check the plugin for additional configuration options."

            }
            catch [System.Net.WebException]
            {
                write-error $_.Exception.ToString()
                return
            }
        }
        
    }

}

function Remove-VCheckPlugin
{
    <#
        .SYNOPSIS
        
        Removes a vCheck plugin.

        .DESCRIPTION
        
        Remove-VCheckPlugin Uninstalls a vCheck Plugin.
        
        Basically, just looks for the plugin name and deletes the file. Sure, you could just delete the ps1 file from the plugins folder, but what fun is that?

        
        .PARAMETER name

        Name of the plugin.

        .EXAMPLE

        Remove via pipeline

        Get-VCheckPlugin "Plugin name" | Remove-VCheckPlugin

        
        .EXAMPLE

        Remove Plugin by name

        Remove-VCheckPlugin "Plugin name"

    #>
    [CmdletBinding(DefaultParametersetName="name",SupportsShouldProcess=$true,ConfirmImpact="High")]
    Param
    (
        [Parameter(parameterSetName="name",Position=0,mandatory=$true)] [String]$name,
        [Parameter(parameterSetName="object",Position=0,mandatory=$true,ValueFromPipeline=$true)] [PSObject]$pluginobject
    )
    Process
    {
        if($name)
        {
            Get-VCheckPlugin $name | Remove-VCheckPlugin
        }
        elseif ($pluginObject)
        {
           Remove-Item -path ("$vCheckPath\plugins\$($pluginobject.location)") -confirm:$false
        }
        
    }

}

Function Get-vCheckCommand {
	Get-Command *vCheck*
}

Get-vCheckCommand
