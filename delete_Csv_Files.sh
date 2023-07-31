allThreads=("checks.csv" "friends.csv" "p2p.csv" "peers.csv" "recommendations.csv" "tasks.csv" "timetracking.csv" "transferredpoints.csv" "verter.csv" "xp.csv")
for item in ${!allThreads[*]}
do
    if [ -f ${allThreads[item]} ]; then
    rm ${allThreads[item]}
    echo  "$item ${allThreads[item]}" "удален" |  awk '{print $1 " " $3  " ->",  $2}'| column -t
    else
    echo  "$item ${allThreads[item]}" "отсутствует" |  awk '{print $1 " " $3  " ->",  $2}'| column -t
    fi
done