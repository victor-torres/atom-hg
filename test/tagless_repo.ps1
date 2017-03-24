hg init $args[0]
set-location $args[0]

new-item -type File "clean_file"
hg add "clean_file"
hg commit -m "Commit 1" -u "Tester <test@test.com>"
hg prev
