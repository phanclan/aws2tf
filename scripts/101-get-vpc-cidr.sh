#!/bin/bash
if [ "$1" != "" ]; then
    cmd[0]="$AWS ec2 describe-vpcs --filters \"Name=vpc-id,Values=$1\"" 
else
    cmd[0]="$AWS ec2 describe-vpcs"
fi

pref[0]="Vpcs[].CidrBlockAssociationSet"
tft[0]="aws_vpc_ipv4_cidr_block_association"
idfilt[0]="AssociationId"

#rm -f ${tft[0]}.tf

for c in `seq 0 0`; do
    
    cm=${cmd[$c]}
	ttft=${tft[(${c})]}
	#echo $cm
    awsout=`eval $cm`
    count=`echo $awsout | jq ".${pref[(${c})]} | length"`
    echo "count=$count"
    if [ "$count" == "" ]; then count=0 ; fi
    if [ "$count" -gt "0" ]; then
        count=`expr $count - 1`
        for i in `seq 0 $count`; do
            #echo $i
            basecidr=`echo $awsout | jq ".Vpcs[0].CidrBlock"`
            thiscidr=`echo $awsout | jq ".${pref[(${c})]}[(${i})].CidrBlock"`
            #echo "$basecidr $thiscidr"
            if [ $basecidr != $thiscidr ]; then
                cname=`echo $awsout | jq ".${pref[(${c})]}[(${i})].${idfilt[(${c})]}" | tr -d '"'`
                echo $cname
                fn=`printf "%s__%s.tf" $ttft $cname`
                printf "resource \"%s\" \"%s\" {" $ttft $cname > $ttft.$cname.tf
                printf "}" $cname >> $ttft.$cname.tf
                terraform import $ttft.$cname $cname
                terraform state show $ttft.$cname > t2.txt
                tfa=`printf "%s.%s" $ttft $cname`
                terraform show  -json | jq --arg myt "$tfa" '.values.root_module.resources[] | select(.address==$myt)' > $tfa.json
                #echo $awsj | jq . 
                rm $ttft.$cname.tf
                cat t2.txt | perl -pe 's/\x1b.*?[mGKH]//g' > t1.txt
                #	for k in `cat t1.txt`; do
                #		echo $k
                #	done
                file="t1.txt"
                echo $aws2tfmess > $fn
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
                        if [[ ${tt1} == "owner_id" ]];then skip=1;fi
                        if [[ ${tt1} == "ipv6_cidr_block_association_id" ]];then skip=1;fi
                        #if [[ ${tt1} == "availability_zone" ]];then skip=1;fi
                        if [[ ${tt1} == "availability_zone_id" ]];then skip=1;fi
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
            fi
        done
    fi
done
terraform fmt
terraform validate
rm -f t*.txt

