#!/bin/bash


###################
### DEFINITIONS ###
###################
SSHD_FILE=/etc/ssh/sshd_config
PASSWD_FILE=/etc/passwd
DATETIME=`date +%Y%m%d-%H%M%S`
CP=`which cp`
SED=`which sed`
SSHD=`which sshd`
HOSTNAMECTL=`which hostnamectl`
NMCLI=`which nmcli`
AWK=`which awk`
GREP=`which grep`
PWCK=`which pwck`
IFNAME="eth0"
SYSTEMCTL=`which systemctl`
IFCFG_ETH0_FILE=/etc/sysconfig/network-scripts/ifcfg-${IFNAME}


#################
### FUNCTIONS ###
#################
CHECK_FILE_EXISTS() {
	FILE=$1

	if [ ! -f ${FILE} ]; then
		echo "${FILE} does not exist. Exiting now..."
		exit 999
	fi
}

IS_EMPTY() {
	VAR=$1

	if [[ -z "${VAR}" ]]; then
		return 0
	else
		return 998
	fi
}

CHECK_RETURN_VALUE() {
	retVal=$1
	funcName=$2

	if [ ${retVal} -ne 0 ]; then
		echo "Error in ${funcName}. Exiting now..."
		exit $retVal
	fi
}

SET_HOSTNAME() {
	SERVER_HOSTNAME=$1
	if IS_EMPTY ${NEW_HOSTNAME}; then
		return 997
	fi

	${HOSTNAMECTL} set-hostname ${SERVER_HOSTNAME}
	returnValue=$?
	CHECK_RETURN_VALUE ${returnValue} "<Setting Hostname>"
	echo "Hostname set to ${SERVER_HOSTNAME}."
}

SET_IP() {
	SERVER_IP=$1
	SERVER_PREFIX=$2

	if IS_EMPTY ${SERVER_IP} && IS_EMPTY ${SERVER_PREFIX}; then
		return 997
	elif IS_EMPTY ${SERVER_IP}; then
		SERVER_IP=`${GREP} IPADDR ${IFCFG_ETH0_FILE} | ${AWK} -F= '{print $2}'`
	elif IS_EMPTY ${SERVER_PREFIX}; then
		SERVER_PREFIX=`${GREP} PREFIX ${IFCFG_ETH0_FILE} | ${AWK} -F= '{print $2}'`
	fi
	SERVER_FULL_IP="${SERVER_IP}/${SERVER_PREFIX}"

	${NMCLI} conn mod ${IFNAME} ipv4.addresses ${SERVER_FULL_IP}
	returnValue=$?
	CHECK_RETURN_VALUE ${returnValue} "<Setting IP and Subnet>"
	echo "IP and Subnet set to ${SERVER_FULL_IP} for ${IFNAME}."
}

UPDATE_LISTENADDRESS() {
	NEW_IP=$1
	if IS_EMPTY ${NEW_IP}; then
		return 997
	fi

	${CP} -p ${SSHD_FILE} ${SSHD_FILE}.${DATETIME}
	${SED} -i "s/^ListenAddress.*/ListenAddress ${NEW_IP}:22/g" ${SSHD_FILE}
	returnValue=$?
	CHECK_RETURN_VALUE ${returnValue} "<Update ListenAddress in ${SSHD_FILE}.>"
	${SSHD} -t
	returnValue=$?
	CHECK_RETURN_VALUE ${returnValue} "<Verify ${SSHD_FILE}.>"
	echo "ListenAddress updated to ${NEW_IP}:22 in ${SSHD_FILE}."
}

SET_GATEWAY() {
	SERVER_GATEWAY=$1
	if IS_EMPTY ${SERVER_GATEWAY}; then
		return 997
	fi

	${NMCLI} conn mod ${IFNAME} ipv4.gateway ${SERVER_GATEWAY}
	returnValue=$?
	CHECK_RETURN_VALUE ${returnValue} "<Setting Gateway>"
	echo "Gateway set to ${SERVER_GATEWAY} for ${IFNAME}."
}

ENABLE_NEW_NETWORK_SETTINGS() {
	echo "Applying new network settings for ${IFNAME}..."
	${NMCLI} conn reload
	${NMCLI} conn down ${IFNAME} && ${NMCLI} conn up ${IFNAME}
}

RESTART_SSHD() {
	${SYSTEMCTL} restart sshd
	returnValue=$?
	CHECK_RETURN_VALUE ${returnValue} "<Restart SSHD service>"
}

ROOT_ACCOUNT() {
	DISABLE_ROOT=$1

	if [ "${DISABLE_ROOT}" == "YES" ]; then
		${GREP} -e "^root.*.sbin.nologin" ${PASSWD_FILE}
		if [ "$?" -ne 0 ]; then
			${CP} -p ${PASSWD_FILE} ${PASSWD_FILE}.${DATETIME}
			${SED} -i "s/^root.*/root:x:0:0:root:\/root:\/sbin\/nologin/g" ${PASSWD_FILE}
			${PWCK} -qr ${PASSWD_FILE}
			returnValue=$?
			CHECK_RETURN_VALUE ${returnValue} "<Changing root login to /sbin/nologin>"
		fi
		echo "Root account disabled."
		rootAccountStatus="disabled"
	else
		${GREP} -e "^root.*.bin.bash" ${PASSWD_FILE}
		if [ "$?" -ne 0 ]; then
			${CP} -p ${PASSWD_FILE} ${PASSWD_FILE}.${DATETIME}
			${SED} -i "s/^root.*/root:x:0:0:root:\/root:\/bin\/bash/g" ${PASSWD_FILE}
			${PWCK} -qr ${PASSWD_FILE}
			returnValue=$?
			CHECK_RETURN_VALUE ${returnValue} "<Changing root login to /bin/bash>"	
		fi
		echo "Root account not disabled."
	fi
}

NETWORK_SETTINGS() {
	APPLY_NETWORK=$1

	if [ "${APPLY_NETWORK}" == "YES" ]; then
		ENABLE_NEW_NETWORK_SETTINGS
		RESTART_SSHD
		echo "Network settings applied."
	else
		echo "Network settings not applied. Please manually apply."
	fi
}


############
### MAIN ###
############
# CHECKS
CHECK_FILE_EXISTS "${SSHD_FILE}"
CHECK_FILE_EXISTS "${PASSWD_FILE}"

# HOSTNAME
echo "[HOSTNAME]"
read -p "Enter the hostname (leave blank to skip): " NEW_HOSTNAME
SET_HOSTNAME "${NEW_HOSTNAME}"

# IP ADDRESS / PREFIX
echo ""
echo "[NETWORK]"
read -p "Enter the IP Address, eg: 192.0.0.1 (leave blank to skip): " NEW_IP

echo ""
read -p "Enter the Subnet Prefix, eg: 24 (leave blank to skip): " NEW_PREFIX
SET_IP "${NEW_IP}" "${NEW_PREFIX}"
UPDATE_LISTENADDRESS "${NEW_IP}"

# GATEWAY
echo ""
read -p "Enter the Gateway, eg: 192.0.0.254 (leave blank to skip): " NEW_GATEWAY
SET_GATEWAY "${NEW_GATEWAY}"

# DISABLE ROOT
echo ""
echo "[ROOT ACCOUNT]"
rootAccountStatus="enabled"
read -p "Disable root account? [YES / NO]: " TO_DISABLE_ROOT_ACCOUNT
ROOT_ACCOUNT "${TO_DISABLE_ROOT_ACCOUNT}"

# ENABLE NEW NETWORK & RESTART SSHD
if !( IS_EMPTY ${SERVER_IP} && IS_EMPTY ${SERVER_PREFIX} ); then
	echo ""
	echo "[APPLY NETWORK SETTINGS]"
	rootAccountStatus="enabled"
	read -p "Apply network settings (Note: Session may be disconnected if accessed by SSH)? [YES / NO]: " APPLY_NETWORK_SETTINGS
	NETWORK_SETTINGS "${APPLY_NETWORK_SETTINGS}"
fi

# SUMMARY
echo ""
echo -e "[SUMMARY]
Hostname: ${NEW_HOSTNAME}
IP Address: ${NEW_IP}
Subnet Mask: ${NEW_PREFIX}
Gateway: ${NEW_GATEWAY}
Root Account: ${rootAccountStatus}
"
