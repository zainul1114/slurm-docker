#!/bin/bash
set -e

if [ "$1" = "slurmdbd" ]
then
    echo "---> Starting the MUNGE Authentication service (munged) ..."
    if [ ! -e /etc/munge/munge.key ]
    then
	/usr/sbin/create-munge-key
        chown -R munge:munge /etc/munge
        chmod 700 /etc/munge
    fi
    #this should likely be removed, but had some issues with munge perms
    chown -R slurm:slurm /var/*/slurm*
    chown -R munge:munge /etc/munge
    chmod 700 /etc/munge
    chown -R munge:munge /var/run/munge
    gosu munge /usr/sbin/munged

    echo "---> Starting the Slurm Database Daemon (slurmdbd) ..."

    {
        . /etc/slurm/slurmdbd.conf
        until echo "SELECT 1" | mysql -h $StorageHost -u$StorageUser -p$StoragePass 2>&1 > /dev/null
        do
            echo "-- Waiting for database to become active ..."
            sleep 2
        done
    }
    echo "-- Database is now active ..."

    exec gosu slurm /usr/sbin/slurmdbd -Dvvv
fi

if [ "$1" = "slurmctld" ]
then
    if [ ! -e /etc/munge/munge.key ]
    then
        /usr/sbin/create-munge-key
        chown -R munge:munge /etc/munge
        chmod 700 /etc/munge
    fi
    #this should likely be removed, but had some issues with munge perms
    chown -R slurm:slurm /var/*/slurm*
    chown -R munge:munge /etc/munge
    chmod 700 /etc/munge
    chown -R munge:munge /var/run/munge    
    echo "---> Starting the MUNGE Authentication service (munged) ..."
    gosu munge /usr/sbin/munged

    echo "---> Waiting for slurmdbd to become active before starting slurmctld ..."

    until 2>/dev/null >/dev/tcp/slurmdbd/6819
    do
        echo "-- slurmdbd is not available.  Sleeping ..."
        sleep 2
    done
    echo "-- slurmdbd is now active ..."

    echo "---> Starting the Slurm Controller Daemon (slurmctld) ..."
    exec gosu slurm /usr/sbin/slurmctld -iDvvv
fi

if [ "$1" = "slurmd" ]
then
    if [ ! -e /etc/munge/munge.key ]
    then
        /usr/sbin/create-munge-key
        chown -R munge:munge /etc/munge
        chmod 700 /etc/munge
    fi
    #this should likely be removed, but had some issues with munge perms
    chown -R slurm:slurm /var/*/slurm*
    chown -R munge:munge /etc/munge
    chmod 700 /etc/munge
    chown -R munge:munge /var/run/munge
    echo "---> Starting the MUNGE Authentication service (munged) ..."
    gosu munge /usr/sbin/munged

    echo "---> Waiting for slurmctld to become active before starting slurmd..."

    until 2>/dev/null >/dev/tcp/slurmctld/6817
    do
        echo "-- slurmctld is not available.  Sleeping ..."
        sleep 2
    done
    echo "-- slurmctld is now active ..."

    echo "---> Starting the Slurm Node Daemon (slurmd) ..."
    exec /usr/sbin/slurmd -Dvvv
fi

exec "$@"