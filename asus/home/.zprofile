# Load the same login environment bash gets (PATH, /etc/profile.d, ~/.profile).
[[ -r /etc/profile ]] && emulate sh -c '. /etc/profile'
[[ -r ~/.profile ]]   && emulate sh -c '. ~/.profile'
