Configuration MyWebConfig
{
 # Import custom resources from the module that defines it

Import-DscResource -Module xWebAdministration  
   # A Configuration block can have zero or more Node blocks
   Node "WIN2012R2"
   {
      # Next, specify one or more resource blocks

      # WindowsFeature is one of the built-in resources you can use in a Node block
      # This example ensures the Web Server (IIS) role is installed
      WindowsFeature Roles
      {
          Ensure = "Present" # To uninstall the role, set Ensure to "Absent"
          Name = "Web-Server"  
      }
      WindowsFeature Jizz
      {
          Ensure = "Present" # To uninstall the role, set Ensure to "Absent"
          Name = "Web-Mgmt-Console"  
      }

      WindowsFeature AspNet45 

        {
            Ensure = "Present"
            Name = "Web-Asp-Net45"
        }
 
# Create the new Website
        xWebsite BobDSCTest
        {
            Ensure          = "Present"
            Name            = "BobTest"
            State           = "Started"
            PhysicalPath    = "C:\Inetpub\wwwroot\bobtest"
            DependsOn       = "[WindowsFeature]Roles"
        }

      # File is a built-in resource you can use to manage files and directories
      # This example ensures files from the source directory are present in the destination directory
      File WebContent
      {
         Ensure = "Present"  # You can also set Ensure to "Absent"
         Type = "Directory" # Default is “File”
         Recurse = $true
         SourcePath = "C:\WebSource" # This is a path that has web files
         DestinationPath = "C:\inetpub\wwwroot\bobtest" # The path where we want to ensure the web files are present
         DependsOn = "[WindowsFeature]Roles"  # This ensures that Role completes successfully before this block runs
       }


      
   }
} 