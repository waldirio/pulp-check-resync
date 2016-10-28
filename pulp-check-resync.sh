#!/bin/bash

#
# Date ......: 07/29/2016
# Developer .: Waldirio M Pinheiro <waldirio@redhat.com>
# Purpose ...: Resync local files (rpm) from pulp repos
# Changelog .:
#		10/28/2016 - Test if there are pulp-admin* packages installed.
#              


LOCALDATE="date +%m-%d-%Y-%H-%M-%S"
LOG="/var/log/pulp-check-resync.log"
PULP_USER="admin"
PULP_PASSWD=$(grep ^default_password /etc/pulp/server.conf |cut -f2 -d: | sed -e 's/ //')
PULP_CMD="pulp-admin -u admin -p $PULP_PASSWD"

testConn()
{

  echo "Started $($LOCALDATE)"						| tee -a $LOG

  testPackage=$(rpm -qa |grep -E '(pulp-admin-client|pulp-rpm-admin-extensions|pulp-rpm-handlers)'|wc -l)

  if [ $testPackage -ne 3 ]; then
    echo "Will be necessary install pulp-admin packages, please run command below."
    echo "# yum install -y pulp-admin-client pulp-rpm-admin-extensions pulp-rpm-handlers"
    exit 1
  fi
  

  pulp-admin tasks list 1>/dev/null 2>/dev/null
  testPulpConn=$?

  if [ $testPulpConn -ne 0 ]; then
    echo "Erro connecting with pulp, trying to connect ..."		| tee -a $LOG
    pulp_conn
  else
    echo "Connected to PULP"						| tee -a $LOG
  fi
}

pulp_conn()
{
  pulp-admin login -u admin -p $PULP_PASSWD
  testPulpLogin=$?

  if [ $testPulpLogin -ne 0 ]; then
    echo "Erro connecting to pulp using User: admin and Password:$PULP_PASSWD"	| tee -a $LOG
    exit 1
  else
    echo "Connected with successful"						| tee -a $LOG
  fi
}

listRepos()
{
  # just for debug
  # listReposFull="ACME-Red_Hat_Enterprise_Linux_Server-Red_Hat_Enterprise_Linux_7_Server_-_Optional_RPMs_x86_64_7Server"
  listReposFull=$($PULP_CMD repo list |grep -A 2 Id | sed -e '/^Display/d' -e '/^--/d'  | sed -e 's/ *//' | grep -v "Description: "  | sed -e 's/^Id:                  /,/' | tr '\n' ' ' | sed -e 's/ //g' | tr ',' '\n')

  for b in $listReposFull
  do
    echo "Repo: $b"								| tee -a $LOG
    syncRepo $b
  done

}

syncRepo()
{
  localRepo=$1

  echo "Checking for removed files"						| tee -a $LOG
  $PULP_CMD rpm repo remove rpm --repo-id $localRepo -a 2000-01-01		| tee -a $LOG

  echo "Updading the repo (--skip=rpm)"						| tee -a $LOG
  $PULP_CMD rpm repo update --skip=rpm --repo-id $localRepo			| tee -a $LOG

  echo "Syncing repo"								| tee -a $LOG
  $PULP_CMD rpm repo sync run --repo-id $localRepo				| tee -a $LOG

  echo "Updading the repo (--skip=)"						| tee -a $LOG
  $PULP_CMD rpm repo update --skip= --repo-id $localRepo			| tee -a $LOG

  echo "Syncing repo"								| tee -a $LOG
  $PULP_CMD rpm repo sync run --repo-id $localRepo				| tee -a $LOG
}

endConn()
{
  echo "Finished $($LOCALDATE)"							| tee -a $LOG
}


# Main
testConn
listRepos
endConn
