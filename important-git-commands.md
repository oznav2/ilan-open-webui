git pull origin main | cat 

# Stash your local changes first, then pull and reapply them

git stash | cat && git pull origin main | cat && git stash pop | cat