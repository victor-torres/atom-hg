hg init $args[0]
set-location $args[0]

Set-Content -Path ".hgignore" -Value @"
syntax:glob
ignored_file
"@
hg add ".hgignore"

new-item -type File "ignored_file"
new-item -type Directory "subdir"
new-item -type File "subdir/some_file"

$subDir = get-item "subdir"
$path = $subDir.FullName
$path = $path.PadRight(259, "A")

rename-item "subdir" (Split-Path $path -Leaf)
