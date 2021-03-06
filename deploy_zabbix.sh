#!/usr/bin/env ksh
SOURCE_DIR=$(dirname $0)
ZABBIX_DIR=/etc/zabbix

OPENVPN_LISTEN="${1:-0.0.0.0}"
OPENVPN_PORT="${2:-1194}"
OPENVPN_STATUS="${3:-/etc/openvpn/openvpn-status.log}"
OPENVPN_CCD="${4:-/etc/openvpn/ccd}"

mkdir -p ${ZABBIX_DIR}/scripts/agentd/zaovpn
cp ${SOURCE_DIR}/zaovpn/zaovpn.conf.example ${ZABBIX_DIR}/scripts/agentd/zaovpn/zaovpn.conf
cp ${SOURCE_DIR}/zaovpn/zaovpn.sh ${ZABBIX_DIR}/scripts/agentd/zaovpn/
cp ${SOURCE_DIR}/zaovpn/zabbix_agentd.conf ${ZABBIX_DIR}/zabbix_agentd.d/zaovpn.conf
sed -i "s|OPENVPN_LISTEN=.*|OPENVPN_LISTEN=\"${OPENVPN_LISTEN}\"|g" ${ZABBIX_DIR}/scripts/agentd/zaovpn/zaovpn.conf
sed -i "s|OPENVPN_PORT=.*|OPENVPN_PORT=\"${OPENVPN_PORT}\"|g" ${ZABBIX_DIR}/scripts/agentd/zaovpn/zaovpn.conf
sed -i "s|OPENVPN_STATUS=.*|OPENVPN_STATUS=\"${OPENVPN_STATUS}\"|g" ${ZABBIX_DIR}/scripts/agentd/zaovpn/zaovpn.conf
sed -i "s|OPENVPN_CCD=.*|OPENVPN_CCD=\"${OPENVPN_CCD}\"|g" ${ZABBIX_DIR}/scripts/agentd/zaovpn/zaovpn.conf
