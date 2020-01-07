#1/bin/bash
if [ "$1" != "" ]; then
    cmd[0]="aws ec2 describe-security-groups --filters \"Name=vpc-id,Values=$1\"" 
else
    cmd[0]="aws ec2 describe-security-groups"
fi

pref[0]="SecurityGroups"
tft[0]="aws_security_group"

for c in `seq 0 0`; do
 
    cm=${cmd[$c]}
	ttft=${tft[(${c})]}
	#echo $cm
    awsout=`eval $cm`
    count=`echo $awsout | jq ".${pref[(${c})]} | length"`
    if [ "$count" -gt "0" ]; then
        count=`expr $count - 1`
        for i in `seq 0 $count`; do
            #echo $i
            gname=`echo $awsout | jq ".${pref[(${c})]}[(${i})].GroupName" | tr -d '"'`
            if [ "$gname" != "default" ]; then
                cname=`echo $awsout | jq ".${pref[(${c})]}[(${i})].GroupId" | tr -d '"'`
                desc=`echo $awsout | jq ".${pref[(${c})]}[(${i})].Description" | tr -d '"'`
                echo $cname
                fn=`printf "%s__%s.tf" $ttft $cname`
                printf "resource \"%s\" \"%s\" {\n" $ttft $cname > $fn
# sg stuff
                printf "description = \"%s\"\n" "$desc" >> $fn


                printf "}\n" $cname >> $fn
                terraform import $ttft.$cname $cname
                
            fi
        done
    fi
done
# cleanup tf aws_security_group_rule state - autogenerated
#
terraform state list | grep aws_security_group_rule > tf1.tmp
for i in `cat tf1.tmp` ; do
    terraform state show $i > t2.txt
    echo $i
    ttft=`echo $i | cut -d'.' -f1`
    cname=`echo $i | cut -d'.' -f2`
    
    cat t2.txt | perl -pe 's/\x1b.*?[mGKH]//g' > t1.txt

    file="t1.txt"
    fn=`printf "%s.tf" $i`
    echo "$fn $ttft $cname"
                while IFS= read line
                do
                    skip=0
                    # display $line or do something with $line
                    t1=`echo "$line"` 
                    if [[ ${t1} == *"="* ]];then
                        tt1=`echo "$line" | cut -f1 -d'=' | tr -d ' '` 
                        tt2=`echo "$line" | cut -f2- -d'='`
                        if [[ ${tt1} == "arn" ]];then skip=1; fi                
                        if [[ ${tt1} == "id" ]];then skip=1; fi          
                        if [[ ${tt1} == "role_arn" ]];then skip=1;fi
                        #if [[ ${tt1} == "owner_id" ]];then skip=1;fi
                        #if [[ ${tt1} == "availability_zone" ]];then skip=1;fi
                        #if [[ ${tt1} == "availability_zone_id" ]];then skip=1;fi
                        #if [[ ${tt1} == "default_route_table_id" ]];then skip=1;fi
                        if [[ ${tt1} == "owner_id" ]];then skip=1;fi
                        #if [[ ${tt1} == "default_network_acl_id" ]];then skip=1;fi
                        #if [[ ${tt1} == "ipv6_association_id" ]];then skip=1;fi
                        #if [[ ${tt1} == "ipv6_cidr_block" ]];then skip=1;fi
                        if [[ ${tt1} == "vpc_id" ]]; then
                            tt2=`echo $tt2 | tr -d '"'`
                            t1=`printf "%s = aws_vpc.%s.id" $tt1 $tt2`
                        fi

                    fi

                    if [ "$skip" == "0" ]; then
                        #echo $skip $t1
                        echo $t1 >> $fn
                    fi
                    
                done <"$file"
done

#terraform fmt
#terraform validate
rm t*.txt tf1.tmp

