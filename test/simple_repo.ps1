hg init $args[0]
set-location $args[0]

("clean_file", "modified_file", "removed_file", "missing_file") | foreach-object {
  new-item -type File $_
  hg add $_
}

new-item -type File "untracked_file"
new-item -type File "ignored_file"

Set-Content -Path "modified_file" -Value @"
1
2
3
4
5
6
7
8
"@
hg commit -m "Commit 1 without ignore" -u "Tester <test@test.com>"
hg tag -lf "commit1"

Set-Content -Path ".hgignore" -Value @"
syntax:glob
ignored_file
"@
hg add ".hgignore"

Set-Content -Path "modified_file" -Value "Some text."

hg commit -m "Commit 2 with ignore" -u "Tester <test@test.com>"
hg bookmark "test-bookmark"
hg tag -lf "test-tag"

Set-Content -Path "modified_file" -Value "Changes!"
hg remove "removed_file"
Remove-Item "missing_file"
