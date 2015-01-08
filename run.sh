rm articles/*
ruby parse-wiki.rb "Russia"
grep -r "\[\[" --color=auto articles/
grep -r "\]\]" --color=auto articles/
grep -r "{{" --color=auto articles/
grep -r "}}" --color=auto articles/