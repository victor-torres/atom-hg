#!/bin/bash

hg init "$1"
ln -s "$1" "$1 symlink"
cd "$1"

files=("clean_file" "modified_file" "removed_file" "missing_file")
for f in ${files[*]}
do
  touch $f
  hg add $f
done
touch "untracked_file"
touch "ignored_file"

echo -e "syntax:glob\nignored_file">".hgignore"
hg add ".hgignore"

hg commit -m "Commit 1" -u "Tester <test@test.com>"
echo -e "Changes!">"modified_file"
hg remove "removed_file"
rm "missing_file"
