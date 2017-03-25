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

echo -e "1\n2\n3\n4\n5\n6\n7\n8">"modified_file"

hg commit -m "Commit 1 without ignore" -u "Tester <test@test.com>"
hg tag -lf "commit1"

echo -e "syntax:glob\nignored_file">".hgignore"
hg add ".hgignore"

echo -e "Some text.">"modified_file"

hg commit -m "Commit 2 with ignore" -u "Tester <test@test.com>"
hg bookmark "test-bookmark"
hg tag -lf "test-tag"

echo -e "Changes!">"modified_file"
hg remove "removed_file"
rm "missing_file"
