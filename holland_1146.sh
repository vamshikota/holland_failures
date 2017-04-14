clear;
underlines() {
for i in $(seq $1); do
        echo -n "="
done
echo
}

singlelines() {
for i in $(seq $1); do
        echo -n "-"
done
echo
}

datadir=$(mysqladmin var  | grep datadir | awk '{print $(NF-1)}')

tmp_tbl=$(mktemp)
for i in $(grep "error: 1146" /var/log/holland/holland.log | awk '{$1=$2=$4="";  print $0}'| sort | uniq ); do echo $i; done | grep -A1 -i "table" | grep -vi "table" | grep [a-z] | sed "s/'//g" | awk -F "."  '{print $1,$2}' >> $tmp_tbl

echo "Problematic Tables are :"
underlines 25
#cat -n $tmp_tbl

echo -e "\n"
seq=1
while read line;  do

        echo -e "$seq - looking at table: $line\n"
        db=$(echo $line | awk '{print $1}');
        tbl=$(echo $line | awk '{print $2}');

        echo -e "Doing show table:"
        singlelines 20
        mysql -B $db -e  "show tables like '$tbl'"

        if [[ $? == 0 ]]; then
                echo "==> Looks OK"
        else
                echo "==> Fail"
        fi;


        echo -e "\n\nDoing describe on table:"
        singlelines 25
        mysql -B $db -e  "desc $tbl"

        if [[ $? == 0 ]]; then
                echo "==> Looks OK"
        else
                echo "==> Fail"
        fi;

        echo -e "\n\nFrom information_schema"
        singlelines 25
        mysql information_schema -Nse "select table_name, table_schema, engine from tables where table_schema='$db' and table_name='$tbl'"

        if [[ $? == 0 ]]; then
                echo "==> Looks OK"
        else
                echo "==> Fail"
        fi;

        echo -e "\n\nLooking at the datadir :"
        singlelines 25
        find $datadir/$db -type f -name "$tbl.*"

        echo -e "\n\n"
        ((seq++))
done < $tmp_tbl

rm -rf $tmp_tbl

