import-module storage


 
function Create-StoragePool {
    param (
        [parameter(Mandatory=$True)] $pool_name = "",
        [parameter(Mandatory=$True)] $num_disks )

    process {
        
        $available_disks = Get-PhysicalDisk | where canpool -eq $true | select -First $num_disks
        if ($available_disks.Length -lt $num_disks) {
            throw "error - not enouch availble disks"
        } else {
            if ( (get-storagepool | where FriendlyName -eq $pool_name) -eq $null ) {

                New-StoragePool -StorageSubSystemUniqueId ( Get-StorageSubSystem -FriendlyName "*Storage Spaces*" ).UniqueId `
                            -FriendlyName $pool_name `
                            -PhysicalDisks $available_disks
             } else {
                #throw "error - pool already created"
             }
        }
    }
}

function Create-LogicalDrive {
    param (
        [parameter(Mandatory=$True)] $logical_drive_name = "",
        [parameter(Mandatory=$True)] $pool_name = "",
        [parameter(Mandatory=$True)] $num_disks
    )

process {
    
        if ( (get-virtualdisk | where FriendlyName -eq $logical_drive_name) -eq $null ) {
            New-VirtualDisk -FriendlyName $logical_drive_name  -StoragePoolFriendlyName $pool_name -UseMaximumSize -ProvisioningType Fixed -ResiliencySettingName Simple -NumberOfColumns $num_disks -Interleave 65536
            
           

        } else {
           # throw "error - Logical Drive already created"
        }

    }
}

function format-Drive {
    param (
        [parameter(Mandatory=$True)] $logical_drive_name = "",
        [parameter(Mandatory=$True)] $drive_letter = "",
        [parameter(Mandatory=$True)] $drive_label = "" 
    )

    process {
    
        $virtual_disk =  Get-VirtualDisk -FriendlyName $logical_drive_name 
        if ($virtual_disk -eq $null ) {
            throw "error - cannot format disk.  No such volume: $logical_drive_name"
        } else {
            $disk_to_format = $virtual_disk | Get-Disk 
            $disk_num = $disk_to_format.Number

            if ($disk_to_format.PartitionStyle -eq "RAW" ) {
                Initialize-disk -Number $disk_num -PartitionStyle GPT
            }

            if ( ((Get-Volume).DriveLetter -contains $drive_letter) -eq $true ) {
                throw "Error - Drive $($drive_letter) already exists"
            } else {
                new-partition -DiskNumber $disk_num  -DriveLetter $drive_letter   -UseMaximumSize 
                Format-Volume -DriveLetter $drive_letter -FileSystem NTFS -AllocationUnitSize 65536 -NewFileSystemLabel $drive_label -confirm:$false 
            }  

        } 
    }
}



 
function Create-StripedDisk {
    param (
        [parameter(Mandatory=$True)] $drive_letter = "",
        [parameter(Mandatory=$True)] $drive_label = "",
        [parameter(Mandatory=$True)] $num_disks,
        [parameter(Mandatory=$False)] $pool_name = "",
        [parameter(Mandatory=$False)] $logical_drive_name = ""
    )

    process {
        
      if ( $pool_name -eq "" ) {
          $pool_name = "pool_$($drive_letter)"
      }

      if ( $logical_drive_name -eq "" ) {
          $logical_drive_name = "logical_drive_$($drive_letter)"
      }

      if ( ((Get-Volume).DriveLetter -contains $drive_letter) -eq $true ) {
           throw "Error - Drive $($drive_letter) already exists"
        } else {
            Create-StoragePool -pool_name $pool_name -num_disks $num_disks 
            Create-LogicalDrive -logical_drive_name $logical_drive_name -pool_name $pool_name -num_disks $num_disks 
            format-Drive -logical_drive_name $logical_drive_name $drive_letter -drive_label $drive_label 
        }
    }
}



Create-StripedDisk -drive_letter "X" -drive_label "Data Drive" -num_disks 10 -pool_name "Data Drive Pool" -logical_drive_name "Data"
Create-StripedDisk -drive_letter "Y" -drive_label "Data Drive" -num_disks 3  -pool_name "TLog Drive Pool" -logical_drive_name "TLog"
Create-StripedDisk -drive_letter "Z" -drive_label "Instrument Drive" -num_disks 2  -pool_name "Instrument Drive Pool" -logical_drive_name "Instrument"
