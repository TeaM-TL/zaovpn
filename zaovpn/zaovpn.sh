#!/usr/bin/env ksh
PATH=/usr/local/bin:${PATH}

#################################################################################

#################################################################################
#
#  Variable Definition
# ---------------------
#
APP_NAME=$(basename $0)
APP_DIR=$(dirname $0)
APP_VER="0.0.1"
APP_WEB="http://www.sergiotocalini.com.ar/"
OPENVPN_LISTEN="0.0.0.0"
OPENVPN_PORT="1194"
OPENVPN_CONF="/etc/openvpn/server.conf"
OPENVPN_STATUS="/etc/openvpn/openvpn-status.log"
OPENVPN_CCD="/etc/openvpn/ccd"
OPENVPN_PKI="/etc/openvpn/pki"
OPENVPN_CERTS="/etc/openvpn/pki/certs"
#
#################################################################################

#################################################################################
#
#  Load Environment
# ------------------
#
[[ -f ${APP_DIR}/${APP_NAME%.*}.conf ]] && . ${APP_DIR}/${APP_NAME%.*}.conf

#
#################################################################################

#################################################################################
#
#  Function Definition
# ---------------------
#
usage() {
    echo "Usage: ${APP_NAME%.*} [Options]"
    echo ""
    echo "Options:"
    echo "  -a            Query arguments."
    echo "  -h            Displays this help message."
    echo "  -j            Jsonify output."
    echo "  -s ARG(str)   Section (status or service)."
    echo "  -v            Show the script version."
    echo ""
    echo "Please send any bug reports to sergiotocalini@gmail.com"
    exit 1
}

version() {
    echo "${APP_NAME%.*} ${APP_VER}"
    exit 1
}

get_service() {
    resource=${1}

    pid=`sudo lsof -Pi TCP@${OPENVPN_LISTEN}:${OPENVPN_PORT} -sTCP:LISTEN -t`
    rcode="${?}"
    if [[ ${resource} == 'listen' ]]; then
	if [[ ${rcode} == 0 ]]; then
	    res=1
	fi
    elif [[ ${resource} == 'uptime' ]]; then
	if [[ ${rcode} == 0 ]]; then
	    res=`sudo ps -p ${pid} -o etimes -h`
	fi
    fi
    echo ${res:-0}
    return 0
}

get_cert() {
    cert="${1}"
    attr="${2}"

    file=`find "${OPENVPN_CERTS}" -name "${cert}*.crt" -print -quit`

    if [[ -n ${file} ]]; then
	OPENVPN_CA=`grep -E "^ca " "${OPENVPN_CONF}" | awk '{print $2}'`
	OPENVPN_CRL=`grep -E "^crl-verify " "${OPENVPN_CONF}" | awk '{print $2}'`	
	if [[ ${attr} == 'status' ]]; then
	    openssl verify -crl_check_all -verbose \
	    	    -CAfile "${OPENVPN_CA}" \
		    -CRLfile "${OPENVPN_CRL}" \
		    "${file}" > /dev/null
	    res="${?}"
	elif [[ ${attr} == 'fingerprint' ]]; then
	    res=`openssl x509 -noout -in ${file} -fingerprint 2>/dev/null|cut -d'=' -f2`	    
	elif [[ ${attr} == 'serial' ]]; then
	    res=`openssl x509 -noout -in ${file} -serial 2>/dev/null|cut -d'=' -f2`
	elif [[ ${attr} == 'before' ]]; then
	    before=`openssl x509 -noout -in ${file} -startdate 2>/dev/null|cut -d'=' -f2`
	    res=`date -d "${before}" +'%s'`
	elif [[ ${attr} == 'after' ]]; then
	    after=`openssl x509 -noout -in ${file} -enddate 2>/dev/null|cut -d'=' -f2`
	    res=`date -d "${after}" +'%s'`
	elif [[ ${attr} == 'expires' ]]; then
	    after=`openssl x509 -noout -in ${file} -enddate 2>/dev/null|cut -d'=' -f2`
	    res=$((($(date -d "${after}" +'%s') - $(date +'%s'))/86400))
	fi
    fi
    echo "${res:-0}"
    return 0    
}

get_status() {
    attr=${1}
    qfilter=${2}

    map="1:common_name;2:real_address;3:bytes_received;4:bytes_sent;5:connected_since"
    if [[ ${attr} == 'bytes_received' ]]; then
	index=3
    elif [[ ${attr} == 'bytes_sent' ]]; then
	index=4
    fi
    
    raw=`sudo awk '/CLIENT LIST/,/ROUTING TABLE/' ${OPENVPN_STATUS} | tail -n +4 | head -n -1`
    if ! [[ -z ${qfilter} ]]; then
	raw=`echo "${raw}" | grep "${qfilter}"`
    fi
    
    if [[ ${index} =~ ^(3|4)$ ]]; then
	res=`echo "${raw}" | awk -F, "{s+=$"${index}"} END {print s}"`
    else
	res=`echo "${raw}" | wc -l`
    fi
    echo ${res}
    return 0
}

discovery() {
    resource=${1}
    
    if [[ ${resource} == 'clients' ]]; then
	for cli in `sudo ls -1 ${OPENVPN_CCD}`; do
	    echo "${cli}"
	done
    elif [[ ${resource} == 'certs' ]]; then
	cafile=`grep -E "^ca " "${OPENVPN_CONF}" | awk '{print $2}'`
	crlfile=`grep -E "^crl-verify " "${OPENVPN_CONF}" | awk '{print $2}'`
	if [[ -z ${OPENVPN_CERTS_LIST} ]]; then
	    certs_files=`find "${OPENVPN_CERTS}" -name "*.crt" -print|sort 2>/dev/null`
	else
	    while read line; do
		file=`find "${OPENVPN_CERTS}" -name "${line}*.crt" -print -quit`
		[[ -z ${file} ]] && continue
		files[${#files[@]}]="${file}"
	    done < <(sort "${OPENVPN_CERTS_LIST}" 2>/dev/null)
	    certs_files=`printf "%s\n" "${files[@]}"`
	fi
	while read cert; do
	    output="`basename ${cert%.crt}`|"
	    while read line; do
		val=`echo ${line}|awk -F'=' '{print $2}'|awk '{$1=$1};1'`
		output+="${val}|"
	    done < <(openssl x509 -noout -in ${cert} -serial -dates 2>/dev/null)
	    openssl verify -crl_check_all -verbose \
	    	    -CAfile "${cafile}" \
		    -CRLfile "${crlfile}" \
		    "${cert}" > /dev/null
	    output="${output%?}|${?}"
	    echo "${output}"
	done < <(printf '%s\n' "${certs_files}")
    else
	echo ${res:-0}
    fi
    return 0
}
#
#################################################################################

#################################################################################
while getopts "s::a:s:uphvj:" OPTION; do
    case ${OPTION} in
	h)
	    usage
	    ;;
	s)
	    SECTION="${OPTARG}"
	    ;;
        j)
            JSON=1
            IFS=":" JSON_ATTR=(${OPTARG//p=})
            ;;
	a)
	    ARGS[${#ARGS[*]}]=${OPTARG//p=}
	    ;;
	v)
	    version
	    ;;
         \?)
            exit 1
            ;;
    esac
done


if [[ ${JSON} -eq 1 ]]; then
    rval=$(discovery ${SECTION} ${ARGS[*]})
    echo '{'
    echo '   "data":['
    count=1
    while read line; do
        IFS="|" values=(${line})
        output='{ '
        for val_index in ${!values[*]}; do
            output+='"'{#${JSON_ATTR[${val_index}]:-${val_index}}}'":"'${values[${val_index}]}'"'
            if (( ${val_index}+1 < ${#values[*]} )); then
                output="${output}, "
            fi
        done 
        output+=' }'
        if (( ${count} < `echo ${rval}|wc -l` )); then
            output="${output},"
        fi
        echo "      ${output}"
        let "count=count+1"
    done <<< ${rval}
    echo '   ]'
    echo '}'
else
    if [[ ${SECTION} == 'status' ]]; then
	rval=$( get_status ${ARGS[*]} )
	rcode="${?}"
    elif [[ ${SECTION} == 'cert' ]]; then
	rval=$( get_cert ${ARGS[*]} )
	rcode="${?}"
    elif [[ ${SECTION} == 'service' ]]; then
	rval=$( get_service ${ARGS[*]} )
	rcode="${?}"
    fi
    echo ${rval:-0}
fi

exit ${rcode:-0}
