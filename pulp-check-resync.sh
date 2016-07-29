#!/bin/bash

#
# Date ......: 07/29/2016
# Developer .: Waldirio M Pinheiro <waldirio@redhat.com>
# Purpose ...: Resync local files (rpm) from pulp repos
# Changelog .:
#              


LOCALDATE="date +%m-%d-%Y-%H-%M-%S"
LOG="/var/log/pulp-check-resync.log"
PULP_USER="admin"
PULP_PASSWD=$(grep ^default_password /etc/pulp/server.conf |cut -f2 -d: | sed -e 's/ //')

testConn()
{

  echo "Started $($LOCALDATE)"						| tee -a $LOG
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
  listReposFull=$(pulp-admin repo list |grep -A 2 Id | sed -e '/^Display/d' -e '/^--/d'  | sed -e 's/ *//' | grep -v "Description: "  | sed -e 's/^Id:                  /,/' | tr '\n' ' ' | sed -e 's/ //g' | tr ',' '\n')

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
  pulp-admin rpm repo remove rpm --repo-id $localRepo -a 2000-01-01		| tee -a $LOG

  echo "Updading the repo (--skip=rpm)"						| tee -a $LOG
  pulp-admin rpm repo update --skip=rpm --repo-id $localRepo			| tee -a $LOG

  echo "Syncing repo"								| tee -a $LOG
  pulp-admin rpm repo sync run --repo-id $localRepo				| tee -a $LOG

  echo "Updading the repo (--skip=)"						| tee -a $LOG
  pulp-admin rpm repo update --skip= --repo-id $localRepo			| tee -a $LOG

  echo "Syncing repo"								| tee -a $LOG
  pulp-admin rpm repo sync run --repo-id $localRepo				| tee -a $LOG
}

endConn()
{
  echo "Finished $($LOCALDATE)"							| tee -a $LOG
}


# Main
testConn
listRepos
endConn
