$password = Read-Host "Enter the password"
$mypwd = ConvertTo-SecureString -String $password -Force –AsPlainText
$CertFilePath = Read-Host "Enter full path and filename to certifcate"
Import-PfxCertificate -FilePath $CertFilePath -CertStoreLocation cert:\LocalMachine\My -Exportable -password  $mypwd
