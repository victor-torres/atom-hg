hg init $args[0]
set-location $args[0]

new-item -type File "clean_file"
hg add "clean_file"
hg commit -m "Commit 1" -u "Tester <test@test.com>"

new-item -type File "clean_file2"
hg add "clean_file2"
hg commit -m "Commit 2" -u "Tester <test@test.com>"

hg checkout -r -2
