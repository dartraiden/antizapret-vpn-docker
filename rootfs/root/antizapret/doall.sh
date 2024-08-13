#!/bin/bash -e


HERE="$(dirname "$(readlink -f "${0}")")"
cd "$HERE"


FORCE=${FORCE:-false}

STAGE_1=${STAGE_1:-false}
STAGE_2=${STAGE_2:-false}
STAGE_3=${STAGE_3:-true}

FILES=(
    temp/list.csv
    temp/nxdomain.txt
    temp/exclude-hosts.txt
    temp/exclude-ips.txt
    temp/hostlist_original_with_include.txt
    temp/include-hosts.txt
    temp/include-ips.txt
    result/blocked-ranges.txt
    result/dnsmasq-aliases-alt.conf
    result/hostlist_original.txt
    result/hostlist_zones.txt
    result/iplist_all.txt
    result/iplist_blockedbyip.txt
    result/iplist_blockedbyip_noid2971.txt
    result/iplist_special_range.txt
    result/knot-aliases-alt.conf
    result/openvpn-blocked-ranges.txt
    result/squid-whitelist-zones.conf
)


create_hash () {
    path=./config/custom
    echo $(
        sed -E '/^(#.*)?[[:space:]]*$/d' $path/*.txt | \
            sort | uniq | sha1sum | awk '{print $1}'
    )
}

diff_hashes () {
    path=./config/custom
    [[ ! -f $path/.hash ]] && create_hash > $path/.hash
    hash_1=$(cat $path/.hash)
    hash_2=$(create_hash)
    if [[ $hash_1 != $hash_2 ]]; then
        echo "Hashes are different: $hash_1 != $hash_2"
        return 1
    else
        echo "Hashes are the same: $hash_1 == $hash_2"
        return 0
    fi
}


# force update
# FORCE=true ./doall.sh
if [[ $FORCE == true ]]; then
    echo 'Force update detected!'
    ./update.sh
    ./parse.sh
    ./process.sh
    exit
fi


for file in ${FILES[@]}; do
    if [ -f $file ]; then
        if test $(find $file -mmin +300); then
            echo "$file is outdated!"
            STAGE_1=true; STAGE_2=true; break
        fi
    else
        echo "$file is missing!"
        [[ $file =~ ^temp/(list.csv|nxdomain.txt)$ ]] && STAGE_1=true
        STAGE_2=true; break
    fi
done


if ! diff_hashes; then create_hash > $path/.hash; STAGE_2=true; fi


[[ $STAGE_1 == true ]] && ./update.sh

[[ $STAGE_2 == true ]] && ./parse.sh || echo 'Nothing to do.'

[[ $STAGE_3 == true ]] && ./process.sh 2> /dev/null